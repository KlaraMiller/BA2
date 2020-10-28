package org.avl.statemachines.stmbot.timeMeasurement

import java.util.Random

/**
 * Simulates waiting times according a random process
 */
class TimeSimulator extends MeanLine {
	boolean indexed_
	Random random_
	double x_	
	double start_time_
	
	new(double offset, double slope, double std_dev, boolean indexed) {
		super (offset, slope, std_dev)
		indexed_ = indexed
		random_ = new Random
		x_ = 0.0
		start_time_ = -1.0
	}
	
	/**
	 * blocks time/waits for a certain time according to the random process 
	 */
	def run() {
		if(!indexed_) {							//!indexed => calculate time stamp (t_)
			if(start_time_<0) {					//if is true only the first time run() is used
				start_time_ = System.nanoTime	//start_time_ is the system time (= a very long number)
			}
			x_ = (System.nanoTime - start_time_) * 1e-9		//calculation so: x_ (in sec) starts with value 0
		}
		val y = Math.abs(OFFSET + SLOPE * x_ + random_.nextGaussian * STD_DEV)		//abs to get no negative values
//		println("Waiting " + y + " seconds")
		println(y)
		Thread.sleep((y*1000).longValue)		//wait y seconds long
		if(indexed_){
			x_++
	//		} else {
	//			val tock = System.nanoTime
	//			x_+=(tock-tick)*1e-9
		}
	}


	// nochmal selbe Funktion nur mit richigen Kommentre
	/**
	 * blocks time/waits for a certain time according to the random process 
	 */
	def run() {

		// if !indexed, calculate x_ as time stamp
		if(!indexed_) {							//!indexed => calculate time stamp
			if(start_time_<0) {					//start_time is true only the first time run() is used
				start_time_ = System.nanoTime	//start_time_ is the system time (= a very long number)
			}
			x_ = (System.nanoTime - start_time_) * 1e-9		//calculating timestemp x_ (in sec), so it starts with value 0
		}

		// calculate waiting times y
		val y = Math.abs(OFFSET + SLOPE * x_ + random_.nextGaussian * STD_DEV)		//using abs to get no negative values
		println("Waiting " + y + " seconds")
		Thread.sleep((y*1000).longValue)		//wait y seconds long
		
		// if indexed, x_ is the number of points (waiting times)
		if(indexed_){
			x_++
		}
	}

}

s