#include "stdlib.h"
#include "sys/alt_stdio.h"
#include <sys/alt_alarm.h>
#include "sys/times.h"
#include "alt_types.h"
#include "system.h"
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include "altera_avalon_pio_regs.h"
#include "sys/alt_irq.h"
#include "sys/alt_cache.h"

// NIOS custom instructions
#define ALT_CI_FP_ALU_FP(n,A,B) __builtin_custom_fnff(ALT_CI_FP_ALU_0_N+(n&ALT_CI_FP_ALU_0_N_MASK),(A),(B))
#define fp_add(A,B) ALT_CI_FP_ALU_FP(0,(A),(B))
#define fp_sub(A,B) ALT_CI_FP_ALU_FP(1,(A),(B))
#define fp_mul(A,B) ALT_CI_FP_ALU_FP(2,(A),(B))
#define fp_div(A,B) ALT_CI_FP_ALU_FP(3,(A),(B))

// invoke the start of HW_det calculations
// A = matrix starting address
// B = dimension
// set B = 0 or 1 to get stage
#define _fp_det_invoke(A,B) __builtin_custom_inpi(ALT_CI_FP_DET_NIOS_0_N,(A),(B))
#define _fp_det_check() _fp_det_invoke(NULL, 0)

#define FP_DET_READY 0
#define FP_DET_ACCEPTED 99
#define FP_DET_READ_SDRAM 1
#define FP_DET_CALCULATING 2
#define FP_DET_WAIT_IRQ 3

#define DIMENSION 3 // Dimension for the matrix to be defined

// PART II
#define hw_notch(A) __builtin_custom_inii(ALT_CI_NOTCH_0_N,(A),0)
#define NOTCH_SIZE 963144
#define NOTCH_ACCEPTED 99
#define NOTCH_READY -1
#define NOTCH_DATA_START (SDRAM_BASE + SDRAM_SPAN/2)

/************************ prototypes ************************************/
/** program stuff **/
float* randomMatrix(int dimension);  // generate matrix
int done = 0;
volatile float det = 0;

/* Software Determinant Stuff */
float determinant(float *matrix, int dimension);
float getAt(float *m, int i, int j, int dimension);
void putAt(float *m, int i, int j, int dimension, float value);

/* hardware determinant stuff */
void _fp_det_isr(void* context);

// two versions of the determinant functions. It is best that users don't mix them. Use one or the other, but never both

// blocking version of HW determinant. Simulate a normal C function
// takes a dimension x dimension matrix pointer. returns results
float fp_det(float *matrix, int dimension);

// interrupt version of the function
// when run, will wait for hardware to be ready
// then sends command and returns status
// when the hardware finishes the calculation, it will call the function provided by func which takes in a float value
int fp_det_interrupt(float *matrix, int dimension, void (*func)(float));

// get the status of the hardware
int fp_det_check();

void (*_fp_det_func)(float) = NULL;
volatile float _fp_det_result = 0;
volatile int _fp_det_done = 0;

/* NOTCH STUFF */
// ISR
void _notch_isr(void* context);
int _notch_status_read(int i);
int notch_read(int offset);

int _notch_done = 0;
int _notch_result = 0;

/*************************** functions ***********************************/
/* Software Determinant Stuff */
float determinant(float *matrix, int dimension){
	int i, j, p;
	float a, result;
	float *m;

	// Let us copy the matrix first
	m = (float *) malloc( sizeof(float)*dimension*dimension );
	memcpy(m, matrix, sizeof(float)*dimension*dimension );

	// First step: perform LU Decomposition using Doolittle's Method
	// This algorithm will return, in the same matrix, a lower unit triangular matrix
	// (i.e. diagonals one)
	// and an upper trangular matrix
	// https://vismor.com/documents/network_analysis/matrix_algorithms/S4.SS2.php

	for (i = 0; i < dimension; i++){
		for (j = 0; j < i; j++){
			a = getAt(m, i, j, dimension);
			for (p = 0; p < j; p++){
				a = fp_sub(a, fp_mul( getAt(m, i, p, dimension), getAt(m, p, j, dimension)) );
			}
			putAt(m, i, j, dimension, fp_div( a, getAt(m, j, j, dimension)));
		}
		for (j = i; j < dimension; j++){
			a = getAt(m, i, j, dimension);
			for (p = 0; p < i; p++){
				a = fp_sub(a, fp_mul( getAt(m, i, p, dimension) , getAt(m, p, j, dimension)));
			}
			putAt(m, i, j, dimension, a);
		}
	}

	// Second step is to find the determinant.
	// Because the lower triangle is a unit triangular matrix
	// the determinant is simply a product of all the upper triangle diagonal
	// which in this case is exactly the diagonal of m
	result = 1;
	for (i = 0; i < dimension; i++)
		result = fp_mul(result, getAt(m, i, i, dimension));

	free(m);

	return result;
}

// Based on i and j, and a float pointer, get the value at row i column j
float getAt(float *m, int i, int j, int dimension){
	return *(m + i*dimension + j);
}

// Based on i and j, and a float pointer, put the value at row i column j
void putAt(float *m, int i, int j, int dimension, float value){
	*(m + i*dimension + j) = value;
}

/** program stuff **/
float * randomMatrix(int dimension){
	int i, j;
	float no;
	float *matrix;

	matrix = (float *) malloc(sizeof(float) * DIMENSION * DIMENSION);
	// Seed
	srand(times(NULL));
	for (i = 0; i < dimension; i++){
		for (j = 0; j < dimension; j++){
			no = ((float) (rand()%100))/50-1;
			*(matrix + i*dimension + j) = no;
		}
	}

	return matrix;
}

void det_done(float result){
	done = 1;
	det = result;
}

/* hardware determinant stuff */
// ISR
void _fp_det_isr(void* context){
	// do some union thingamagick because IORD always interprets result as an int
	// and C does not have reinterpret cast
	union {
		int i;
		float f;
	} result;

	_fp_det_done = 1;
	result.i = IORD(FP_DET_NIOS_0_BASE, 0);
	_fp_det_result = result.f;
	if (_fp_det_func != NULL) _fp_det_func(_fp_det_result);
}

// normal C function
float fp_det(float *matrix, int dimension){
	// check hardware is ready
	while(fp_det_check() != FP_DET_READY);
	_fp_det_done = 0;	// reset done
	_fp_det_invoke((void *) matrix, dimension);

	// now wait for done
	while (!_fp_det_done);
	_fp_det_done = 0;
	return _fp_det_result;
}

// interrupt version - should return FP_DET_ACCEPTED
int fp_det_interrupt(float *matrix, int dimension, void (*func)(float)){
	// check hardware is ready
	while(fp_det_check() != FP_DET_READY);
	_fp_det_done = 0;	// reset done
	_fp_det_func = func;
	return _fp_det_invoke((void *) matrix, dimension);
}

// check status
int fp_det_check(){
	return _fp_det_check();
}

/** NOTCH STUFF **/
void _notch_isr(void* context){
	_notch_done = 1;
	_notch_result = IORD(NOTCH_0_BASE, 0);
}

int _notch_status_read(int i){
	//i *= 4;
	return IORD(NOTCH_0_BASE, i);
}

int notch_read(int offset){
	return IORD(NOTCH_DATA_START, offset);
}

void notch_diagnostic(){
	int i = 0;
	char buffer[11];
	int status = 0;

	alt_putstr("----------Diagnostic-------------\n");
	// 0
	status = _notch_status_read(i++)/4;
	gcvt(status, 10, buffer);
	alt_putstr("readAddress = "); alt_putstr(buffer); alt_putstr("\n");

	// 1
	status = _notch_status_read(i++);
	gcvt(status, 10, buffer);
	alt_putstr("reqFifoUsed = "); alt_putstr(buffer); alt_putstr("\n");

	// 2
	status = _notch_status_read(i++);
	gcvt(status, 10, buffer);
	alt_putstr("readFifoUsed = "); alt_putstr(buffer); alt_putstr("\n");

	//3
	status = _notch_status_read(i++);
	gcvt(status, 10, buffer);
	alt_putstr("sdReceiveCount = "); alt_putstr(buffer); alt_putstr("\n");

	//4
	status = _notch_status_read(i++);
	gcvt(status, 10, buffer);
	alt_putstr("sdDiscardedRead = "); alt_putstr(buffer); alt_putstr("\n");

	//5
	status = _notch_status_read(i++);
	gcvt(status, 10, buffer);
	alt_putstr("calculationStage = "); alt_putstr(buffer); alt_putstr("\n");

	//6
	status = _notch_status_read(i++);
	gcvt(status, 10, buffer);
	alt_putstr("calculationCount = "); alt_putstr(buffer); alt_putstr("\n");

	//7
	status = _notch_status_read(i++)/4;
	gcvt(status, 10, buffer);
	alt_putstr("writeAddress = "); alt_putstr(buffer); alt_putstr("\n");

	//8
	status = _notch_status_read(i++);
	gcvt(status, 10, buffer);
	alt_putstr("writeFifoUsed = "); alt_putstr(buffer); alt_putstr("\n");

	//9
	status = _notch_status_read(i++);
	gcvt(status, 10, buffer);
	alt_putstr("sdread = "); alt_putstr(buffer); alt_putstr("\n");

	//10
	status = _notch_status_read(i++);
	gcvt(status, 10, buffer);
	alt_putstr("sdwaitrequest = "); alt_putstr(buffer); alt_putstr("\n");

	//11
	status = _notch_status_read(i++);
	gcvt(status, 10, buffer);
	alt_putstr("sdwrite = "); alt_putstr(buffer); alt_putstr("\n");

	//12
	status = _notch_status_read(i++);
	gcvt(status, 10, buffer);
	alt_putstr("stage = "); alt_putstr(buffer); alt_putstr("\n");

}

/******************* main ******************/


int main(){
	volatile int i,j;
	volatile int status, status_det, status_notch, previous_det, previous_notch;
	char buffer[11];
	clock_t exec_t1, exec_t2;
	float *matrix;
	//int *wav;

	alt_irq_init(NULL);  // allow for interrupts

	// register ISR - det
	status = alt_ic_isr_register(FP_DET_NIOS_0_IRQ_INTERRUPT_CONTROLLER_ID, FP_DET_NIOS_0_IRQ, _fp_det_isr, NULL, NULL);
	//gcvt(status, 10, buffer);
	//alt_putstr("ISR = "); alt_putstr(buffer); alt_putstr("\n"); // zero is good

	// register ISR - notch
	status = alt_ic_isr_register(NOTCH_0_IRQ_INTERRUPT_CONTROLLER_ID, NOTCH_0_IRQ, _notch_isr, NULL, NULL);
	//gcvt(status, 10, buffer);
	//alt_putstr("ISR = "); alt_putstr(buffer); alt_putstr("\n"); // zero is good

	// setup things - malloc space for output
	//wav = (int *) calloc(NOTCH_SIZE, sizeof(int));
	// ask to overwrite results
	IOWR(NOTCH_0_BASE,0,1);

	// setup things - generate matrix
	matrix = randomMatrix(DIMENSION);	// generate random matrix
	alt_putstr("[");
		for (i = 0; i < DIMENSION; i++){
			for (j = 0; j <  DIMENSION; j++){
				gcvt( *(matrix + i*DIMENSION + j) , 10, buffer);
				alt_putstr(buffer);
				alt_putstr(" ");
			}
			alt_putstr(";\n");
		}
	alt_putstr("]\n");

	// invoke Part II
	status_notch = hw_notch(0);
	gcvt(status_notch, 10, buffer);
	alt_putstr("Notch Ready = "); alt_putstr(buffer); alt_putstr("\n"); // should be NOTCH_ACCEPTED
	previous_notch = status_notch;

	alt_putstr("Notch Invocation = ");
	status_notch = hw_notch(NOTCH_DATA_START);
	gcvt(status_notch, 10, buffer);
	alt_putstr(buffer); alt_putstr("\n"); // should be NOTCH_ACCEPTED
	previous_notch = status_notch;

	// invoke part I
	status_det = fp_det_interrupt((void *) matrix, DIMENSION, det_done);
	gcvt(status_det, 10, buffer);
	alt_putstr("Det Invocation = "); alt_putstr(buffer); alt_putstr("\n");	// should be FP_DET_ACCEPTED
	previous_det = status_det;

	// wait for everything to be done
	while (/*!done ||*/ !_notch_done){

			status_det = fp_det_check();
			if (status_det != previous_det){
				previous_det = status_det;
				gcvt(status_det, 10, buffer);
				alt_putstr("Det Status = "); alt_putstr(buffer); alt_putstr("\n");
			}

			status_notch = hw_notch(0);
			if (status_notch != previous_notch){
				gcvt(status_notch, 10, buffer);
				alt_putstr("Notch Processing = "); alt_putstr(buffer); alt_putstr("\n");
				previous_notch = status_notch;
			}
			else if (!_notch_done){	// diagnostic
				notch_diagnostic();
			}
			else if (_notch_done){
				gcvt(NOTCH_DATA_START, 10, buffer);
				alt_putstr("Notch Result Ptr = "); alt_putstr(buffer); alt_putstr("\n");
			}

	}

	gcvt(det, 10, buffer);
	alt_putstr("Richard calculates = "); alt_putstr(buffer); alt_putstr("\n");

	gcvt(_notch_result, 10, buffer);
	alt_putstr("Notch calculates = "); alt_putstr(buffer); alt_putstr("\n");

	exec_t1 = times(NULL); // get system time before starting the process
	for (i = 0; i < 100; i++){
		det = determinant( matrix, DIMENSION);
	}
	exec_t2 = times(NULL); // get system time after finishing the process
	gcvt(((double)exec_t2-(double)exec_t1) / alt_ticks_per_second(), 10, buffer);
	alt_putstr(" software time = "); alt_putstr(buffer); alt_putstr(" seconds \n");
	alt_putstr("software calculation = ");
	gcvt(det, 10, buffer);
	alt_putstr(buffer);
	alt_putstr("\n");

	//notch_diagnostic();

	alt_putstr("Outputs:\n");
	for (i = 0; i < 30; i++){
		gcvt(notch_read(i), 10, buffer);
		alt_putstr(buffer); alt_putstr("\n");
	}
	/* Event loop never exits. */
	while (1);

	return 0;
}

