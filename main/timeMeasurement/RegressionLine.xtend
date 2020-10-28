package org.avl.statemachines.stmbot.timeMeasurement

import java.util.List
import static extension org.avl.statemachines.stmbot.utils.ListUtils.*

class RegressionLine extends MeanLine implements Hypothesis {
	
	new(double offset, double slope, double std_dev) {
		super(offset, slope, std_dev)
	}
	
	override toString() {
		return '''Offset: «OFFSET» | Slope: «SLOPE» | Standard Deviation: «STD_DEV»'''			// Time transition took, detected drift over time, std-dev
	}
	
	
	/**
	 * Creates a regression line for given data set
	 * @param measured_time_series is a list of data points (data set)
	 * @param indexed if indexed=1: x-axis has index values, if indexed=0: x-axis has time values
	 * @return Regression line with calculated offset, slope and standard deviation
	 */
	// static: function can be used without creating a 'RegressionLine'-object
def static RegressionLine create(DataSeries measured_time_series, boolean indexed) {
	
	val x_all = measured_time_series.getX(indexed)	
	
	//means of indices	
	val indices = measured_time_series.map[INDEX]
	val x_mean = CalculationUtils.mean_double(x_all)		
			
	//mean of y
	val y_all = measured_time_series.map[Y]
	val y_mean = CalculationUtils.mean_double(y_all)	
			
	//calculate variance			
	// calc x_mf
	val x_mf = x_all.map[x|x-x_mean]
	println("x_mf: " + x_mf) // Ausgabe: [D@78e67e0a		
	// calc y_mf
	val y_mf = y_all.map[y|y-y_mean]
	println("y_mf: " + y_mf)
	//calculate square sums etc.
	val s_xy = indices.map[i|x_mf.get(i)*y_mf.get(i)].sum		//using function sum from ListUtils()
	val s_xx = x_mf.map[x|x*x].sum
	val s_yy = y_mf.map[y|y*y].sum
	
	//calculate Parameters a (offset), b (slope)
	val b = s_xy/s_xx
	val a = y_mean - (x_mean * b)		
	
	//calculate y_dach
	val y_dach = x_all.map[x|x*b+a]
	
	//residuals
	val res_all = indices.map[i|y_all.get(i)-y_dach.get(i)]
	val s_res = res_all.map[r|r*r].sum
	
	// variance
	val variance = s_res / (indices.size - 2)
	
	// standard deviation
	val std_dev = Math.sqrt(variance)
	
	return new RegressionLine(a, b, std_dev)		
}	
	
	/**
	 * Creates a regression line for given data set, but with a fixed parameter for slope
	 * @param measured_time_series a list of data points (data set)
	 * @param indexed indexed=1: x-axis has index values; indexed=0: x-axis has time values
	 * @return Regression line with calculated offset and standard deviation
	 */
	def static RegressionLine create(DataSeries measured_time_series, double slope, boolean indexed) {
		
		val x_all = measured_time_series.getX(indexed)	
		
		//means of indices (x)
		val indices = measured_time_series.map[INDEX]
		val x_mean = CalculationUtils.mean_double(x_all)					
		//mean of y
		val y_all = measured_time_series.map[Y]
		val y_mean = CalculationUtils.mean_double(y_all)
		
		//calculate a
		val a = y_mean - (x_mean * slope)
				
		//calculate y_dach
		val y_dach = x_all.map[x|x*slope+a]
		// residuals
		val res_all = indices.map[i|y_all.get(i)-y_dach.get(i)]
		val s_res = res_all.map[r|r*r].sum
		// variance
		val variance = s_res / (indices.size - 1)
		// standard deviation
		val std_dev = Math.sqrt(variance)
		
		return new RegressionLine(a, slope, std_dev)		
	}
	
	/**
	 * Calculates the LogLikelihood of a data set (measured_time_series)
	 */
	override logLikelihood(DataSeries measured_time_series, boolean indexed) {		//takes function from Interface Hypothesis.xtend
			
		val x_all = measured_time_series.getX(indexed)
		var s = 0.0
		
		val term1 = ((-1.0/2.0) * Math.log(2*Math.PI*STD_DEV*STD_DEV))
		//val term1 = (-Math.log(2*Math.PI*STD_DEV*STD_DEV)/2)

		for(d : measured_time_series){
			val term2 = - Math.pow(d.Y-OFFSET-SLOPE*x_all.get(d.INDEX), 2) / (2 * STD_DEV * STD_DEV)
			s += (term1 + term2)
		}
		//println('''s: «s»''')
		return s		
	}		
}