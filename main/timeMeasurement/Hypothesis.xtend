package org.avl.statemachines.stmbot.timeMeasurement

interface Hypothesis {

	/**
	 * Calculates the LogLikelihood of a data set (measured_time_series)
	 */
	def double logLikelihood(DataSeries measured_time_series, boolean indexed) 

}