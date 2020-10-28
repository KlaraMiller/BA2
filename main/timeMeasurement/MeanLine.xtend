package org.avl.statemachines.stmbot.timeMeasurement


/**
 * Class for a straight line, representing 'something' with a mean
 */
abstract class MeanLine {			//can't create an instance of this class
	
	public final double OFFSET		
	public final double SLOPE	
	public final double STD_DEV
	
	new(double offset, double slope, double std_dev) {
		OFFSET = offset
		SLOPE = slope
		STD_DEV = std_dev
	}
	
	override toString()'''Offset: «String.format("%.2f",OFFSET)», STDev: «String.format("%.2e",STD_DEV)», Slope: «String.format("%.2e",SLOPE)»'''
}