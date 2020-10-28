package org.avl.statemachines.stmbot.timeMeasurement

import org.eclipse.xtext.xbase.lib.Procedures.Procedure0
import org.eclipse.xtext.xbase.lib.Functions.Function1

// this function is used in for checkSTMDrift() in TimeMeasurement.xtend
class SPRTExperiment <T extends Hypothesis> {		//T for generic
	
	static final int MAX_ITERS = 100		//constant, not changeable	//50 bei der Platine
	final Procedure0 proc_to_measure_
	final DataSeries data_points_	
	final long start_time_	
	boolean h0_accepted_	
	boolean h1_accepted_
	final int min_iters_	
	final double p_error_
	final boolean indexed_
	final Function1<DataSeries, T> function_h0_
	final Function1<DataSeries, T> function_h1_	
	T result_

	
	new (Procedure0 proc_to_measure, double p_error, int min_iters, boolean indexed, Function1 <DataSeries, T> function_h0, Function1 <DataSeries, T> function_h1) {
		proc_to_measure_ = proc_to_measure
		min_iters_ = min_iters
		data_points_ = new DataSeries
		start_time_ = System.nanoTime
		h0_accepted_ = false
		h1_accepted_ = false	
		function_h0_ = function_h0	
		function_h1_ = function_h1	
		p_error_ = p_error
		indexed_ = indexed		
	}
	
	/**
	 * measures duration of proc_to_measure
	 * @return true if experiment is finished, false otherwise
	 */	
	def measure () {
		
		if (isFinished()) return true
		
		val t = (System.nanoTime - start_time_) * 1e-9						//x-axis		//time in seconds (starts with approx. 0)
		val measured_time = TimeMeasurement.measure(proc_to_measure_)						//y-axis
		data_points_.add(new DataPoint(data_points_.length, t, measured_time))//create data point and add it to data_points array	
				
		val h0 = function_h0_.apply(data_points_) 		//creates hypothesis on data_points_
		val h1 = function_h1_.apply(data_points_) 
		
		//Calculate Sequential Probability Ratio Test (log lamda m)
		val sprt = h1.logLikelihood(data_points_, indexed_) - h0.logLikelihood(data_points_, indexed_)			
		
		//Compare sprt value and calculated boundries with error probability
		h0_accepted_ = (sprt <= Math.log(p_error_/(1-p_error_)))	//hypothesis null is accepted if sprt is smaller than lower boundary
		h1_accepted_ = (sprt >= Math.log((1-p_error_)/p_error_))	//alternative hypothesis is accepted if sprt is bigger than upper boundary	
			
		println('''«data_points_.length».Measurement of current transition | Sprt-Result: «sprt»''')
		
		return isFinished()			//returns TRUE wenn Messung fertig ist (=eine Hypoth ist bestätigt) oder FALSE, wenn noch weitergemessen werden muss							
	}
	
	def isFinished () {	
		return (h0_accepted_ || h1_accepted_ || data_points_.length >= MAX_ITERS) && (data_points_.length >= min_iters_)
	}
	
	def calculateResult() {
		
		if(h0_accepted_) {										
			println('''h null accepted''')
			return function_h0_.apply(data_points_)
		} else if(h1_accepted_) {								
			println('''h alt accepted''')
			return function_h1_.apply(data_points_)	
		} else {
			println('''no hypothesis accepted''')
			return null 			
		}		
	}
	
	def checkHypothesis() {		
		if(!h0_accepted_) return true		//if h alt or none accepted > return true (create RegressionLine nach der Funktionsabfrage)								
	}
	
	def getResult(){
		if(result_ === null){
			result_ = calculateResult
		}
		return result_
	}
	
	def getDataPoints () {				
		//return data_points_.unmodifiableView		//Liste kann nicht geändert werden 
		return new DataSeries (data_points_)		// erstellt neue Liste mit selben Inhalt wie data_points
		
	}
	
}



















