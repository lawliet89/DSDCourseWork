/*
 * "Hello World" example.
 *
 * This example prints 'Hello from Nios II' to the STDOUT stream. It runs on
 * the Nios II 'standard', 'full_featured', 'fast', and 'low_cost' example
 * designs. It runs with or without the MicroC/OS-II RTOS and requires a STDOUT
 * device in your system's hardware.
 * The memory footprint of this hosted application is ~69 kbytes by default
 * using the standard reference design.
 *
 * For a reduced footprint version of this template, and an explanation of how
 * to reduce the memory footprint for a given application, see the
 * "small_hello_world" template.
 *
 */

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

#define ALT_CI_FP_ALU_FP(n,A,B) __builtin_custom_fnff(ALT_CI_FP_ALU_0_N+(n&ALT_CI_FP_ALU_0_N_MASK),(A),(B))
#define fp_add(A,B) ALT_CI_FP_ALU_FP(0,(A),(B))
#define fp_sub(A,B) ALT_CI_FP_ALU_FP(1,(A),(B))
#define fp_mul(A,B) ALT_CI_FP_ALU_FP(2,(A),(B))
#define fp_div(A,B) ALT_CI_FP_ALU_FP(3,(A),(B))
#define fp_det(A,B) __builtin_custom_fnpp(ALT_CI_FP_DET_NIOS_0_N,(A),(B))
#define fp_det_status(A,B) __builtin_custom_inpp(ALT_CI_FP_DET_NIOS_0_N,(A),(B))

#define DIMENSION 5 // Dimension for the matrix to be defined

float determinant(float *matrix, int dimension);
float getAt(float *m, int i, int j, int dimension);
void putAt(float *m, int i, int j, int dimension, float value);
float* randomMatrix(int dimension);
void setDeterminantDimension(int size);

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

void fp_det_isr(void* context){
	// do some union thingamagick because IORD always interprets result as an int
	// and C does not have reinterpret cast
	union {
		int i;
		float f;
	} result;

	done = 1;
	result.i = IORD(FP_DET_NIOS_0_BASE, 0);
	det = result.f;
}

int main(){
	volatile float det = 0.f;
	volatile int i,j;
	char buffer[11];
	char buf[11];
	clock_t exec_t1, exec_t2;
	float *matrix;

	setDeterminantSize(DIMENSION);
	alt_putstr("Hello from Nios II!\n");
	matrix = randomMatrix(DIMENSION);

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

	det = fp_det((void *) matrix, ( void *) &det);
	gcvt(det, 10, buffer);
	//i = fp_det_status((void *) matrix, 0);
	//gcvt(i, 10, buffer);
	alt_putstr("set to = "); alt_putstr(buffer); alt_putstr("\n");

	exec_t1 = times(NULL); // get system time before starting the process
	for (i = 0; i < 100; i++){
		det = determinant( matrix, DIMENSION);
	}
	exec_t2 = times(NULL); // get system time after finishing the process
	gcvt(((double)exec_t2-(double)exec_t1) / alt_ticks_per_second(), 10, buf);

	alt_putstr("software calculation = ");
	gcvt(det, 10, buffer);
	alt_putstr(buffer);
	alt_putstr("\n");
	alt_putstr(" proc time = "); alt_putstr(buf); alt_putstr(" seconds \n");



	/* Event loop never exits. */
	while (1);

	return 0;
}

