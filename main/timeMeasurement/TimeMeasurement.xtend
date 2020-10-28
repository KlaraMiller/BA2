package org.avl.statemachines.stmbot.timeMeasurement

import org.eclipse.xtext.xbase.lib.Procedures.Procedure0
import java.util.ArrayList
import org.avl.statemachines.stmbot.utils.FileUtils
import net.automatalib.automata.transout.MealyMachine
import net.automatalib.words.Alphabet
import de.learnlib.api.SUL
import org.avl.statemachines.stmbot.timeMeasurement.CalculationUtils
import org.avl.statemachines.stmbot.utils.STMUtils
import org.avl.statemachines.stmbot.utils.TransitionData
import java.util.HashMap
import java.util.Map

abstract class TimeMeasurement {			//abstract = can't create an object of this class (not 'instanzierbar')
	static final int MAX_ITERS = 100			//constant; used in checkMaxDrift()		//30 for specificTransTest() in GraduationTest		//50 für Platine
	
	def static measure(Procedure0 proc_to_measure) {		
		 val tick = System.nanoTime
		 proc_to_measure.apply				//executes everything in []
		 val tock = System.nanoTime
		 return (tock - tick) * 1e-9
	}
	
	/**
	 * Measures a process (time series)
	 * @return data_points as ArrayList<DataPoint>
	 */
	def static measureSeries(Procedure0 proc_to_measure, Procedure0 proc_to_prepare, int count) {
		val data_points = new DataSeries
		val start_time = System.nanoTime
		for(i:0..<count) {
			println('''step «i+1» of «count»''')
			proc_to_prepare.apply							//execute process (process 'proc_to_prepare' is not being measured)
			val t = (System.nanoTime - start_time) * 1e-9	//x
			val measured_time = measure(proc_to_measure)	//y		//call function measure() -> .apply -> simulator.run() is executed
			data_points.add(new DataPoint(data_points.length, t, measured_time))	//create data point + add as new value to data_points array
		} 
		return data_points
	}
	
	/**
	 * Measures a process (time series)
	 * @return data_points as ArrayList<DataPoint>
	 */
	def static measureSeries(Procedure0 proc_to_measure, int count) {
		return measureSeries(proc_to_measure, [], count)				//call function measureSeries() without parameter proc_to_prepare
	}	
	
	def static checkMaxDrift(Procedure0 proc_to_measure, Procedure0 proc_to_prepare, double max_slope, double p_error, int min_iters, boolean indexed) {
		return checkMaxDrift(proc_to_measure, proc_to_prepare, max_slope, p_error, min_iters, indexed, 1)
	}
	
	/**
	 * Two regression lines with and without drift are compared via sequential probability ratio test (sprt)
	 * @param proc_to_measure process that the function will measure
	 * @param proc_to_prepare process to prepare takes some time, but isn't measured 
	 * @param max_slope values bigger than max_slope are recognized as drift
	 * @param p_error error probability - e.g p_error = 0.01 means result is correct with a probability of 99%
	 * @param min_iters set minimum number of measured data_points (iterations through data array)
	 * @param indexed 1 = create an index for data point, 0 = create time stamp for data point
	 * @param n_delete number of data points that are removed from measured data ('outliner')
	 * @return regression line without slope (H0), regression line with measured slope (H1)
	 */
	def static checkMaxDrift(Procedure0 proc_to_measure, Procedure0 proc_to_prepare, double max_slope, double p_error, int min_iters, boolean indexed, int n_delete) {
		
		val data_points = new DataSeries
		val start_time = System.nanoTime
		var h_null_accepted = false
		var h_alt_accepted = false		
		var delete = n_delete		//default = 1
		
		//Measure transition times / collect data points, till one of the hypothesis is accepted or MAX_ITERS is reached
		while((!h_null_accepted && !h_alt_accepted && (data_points.length < MAX_ITERS)) || (data_points.length < min_iters)) {
			println('''#########################################################''')		
			proc_to_prepare.apply												//Prozess der nicht mitgemessen werden soll, ausführen
			val t = (System.nanoTime - start_time) * 1e-9						//x-axis		//time in seconds (starts with approx. 0)
			val measured_time = measure(proc_to_measure)						//y-axis
			data_points.add(new DataPoint(data_points.length, t, measured_time))//create data point and add it to data_points array	
			while(delete > 0){
				data_points.remove(0)		//lösche ersten Datenpunkt (so lange bis variable 'delete' 0 ist)
				delete--
			}
			
			// delete first data point
			// data_points.remove(0) > so geht's nicht
			
			// Create 2 regression lines:
			
			val h_null = RegressionLine.create(data_points, 0, indexed)			//line without drift
			val h_alt = RegressionLine.create(data_points, max_slope, indexed)	//line with drift			
			
			//Calculate Sequential Probability Ratio Test (log lamda m)
			val sprt = h_alt.logLikelihood(data_points, indexed) - h_null.logLikelihood(data_points, indexed)			
			
			//Compare sprt value and calculated boundries with error probability
			h_null_accepted = (sprt <= Math.log(p_error/(1-p_error)))	//hypothesis null is accepted if sprt is smaller than lower boundary	
			h_alt_accepted = (sprt >= Math.log((1-p_error)/p_error))	//alternative hypothesis is accepted if sprt is bigger than upper boundary		
			
			println('''«data_points.length».Measurement of current transition | Sprt-Result: «sprt»''')		
		}
		
		CalculationUtils.DataSeriesToFile(data_points, "data_output")
				
		if(h_null_accepted) {										//regression line has no slope
			println('''h null accepted - no slope detected''')
			return RegressionLine.create(data_points, 0, indexed)
		} else if(h_alt_accepted) {									//regression line has a slope	
			println('''h alt accepted - slope detected''')
			return RegressionLine.create(data_points, indexed)		//slope is being calculated in create method
		} else {
			println('''no hypothesis accepted''')
			return RegressionLine.create(data_points, indexed)			
		}
	}
	
	/**
	 * Measures time of statemachine transitions and checks if the transitions drift over time
	 * @param mm mealy-statemachine, is the learned model of sul
	 * @param alphabet input values (Befehle)
	 * @param sul system under learning (system you want to learn)
	 * @param p_error error probability - e.g p_error = 0.01 means result is correct with a probability of 99%
	 * @param min_iters set minimum number of measured data_points (iterations through data array)
	 * @param indexed true = create an index for each measurement, false = create time stamp for each m
	 * @param max_slope a smaller slope than max_slope is not reliably detected
	 */
	def static <S,I,T,O> checkSTMDrift(MealyMachine<S,I,T,O> mm, Alphabet<I> alphabet, SUL<I,O> sul, double p_error, int min_iters, boolean indexed, double max_slope){
				
		val transitions = STMUtils.getTransitions(mm, alphabet)			//iterate through mm (state machine) and get transition in form of: start state, input, output, end state
		val transfer_table = STMUtils.getTransferTable(mm, alphabet)	//create a transfer table out of state machine data	
				
		val timed_transitions = transitions//.filter["WAIA".equals(INPUT_)]		//transitions we want to measure	//filter als Inputs for WAIA and transfer those into a iterable 
		val exp_to_transitions = new HashMap<SPRTExperiment<RegressionLine>,TransitionData<S,I,O>>	//initialisiere HashMap - key: Regression line, attached value: Datenstruktur für eine MM-STM: source(startstate), output(attached to transition), input(Befehl), target(end state)
		for(t : timed_transitions){
			var proc_to_measure = [sul.step(t.INPUT_)] as Procedure0	
			if(#{"WAIA","WAIT"}.contains(t.INPUT_) && t.SOURCE_.equals(t.TARGET_)){
				proc_to_measure = [] as Procedure0
			}																		//create procedure to measure (navigiere an die position in sul)
			val h0 = [DataSeries data_points|RegressionLine.create(data_points, 0, indexed)]			//representiert h0, dass Datenpunkte auf Regressionline ohne drift liegen		//[] function from data series of regression line //line without drift		
			val h1 = [DataSeries data_points|RegressionLine.create(data_points, max_slope, indexed)]	//LR with drift
			exp_to_transitions.put( new SPRTExperiment(proc_to_measure, p_error, min_iters, indexed, h0, h1), t)		//create experiment: RL + ihre Transitionen
		}
		val experiments = exp_to_transitions.keySet				//Menge der Experimente, creates a set of only the keyValues (only regression lines)
		
		var state = mm.initialState
		while(experiments.exists[!finished]){					//while at least one experiment it still running/not finished (meaning sprt is being calculated)
		
			println('''«experiments.filter[!finished].size» Experiments of «experiments.length» running...''')
			
			val candidate_experiments = experiments.filter[!finished]
			val cur_state = state		//current state
			
			// get nearest experiment next to current state
//			val experiment = candidate_experiments.minBy[e|transfer_table.get(cur_state).get(exp_to_transitions.get(e).SOURCE_).length]
			val nearest_experiment = candidate_experiments.minBy[e|
				val transition_to_measure = exp_to_transitions.get(e)		
				val exp_start_state = transition_to_measure.SOURCE_							//get start state of transition of our experiment
				val transfer_sequence = transfer_table.get(cur_state).get(exp_start_state)	//Befehlsreihenfolge als Liste
				return transfer_sequence.length												//length ist die Anzahl der Befehle/Transitionen
			]	// experiment is the nearest experiment next to current state
			
//			val experiment = experiments.findFirst[!finished]
			val transition = exp_to_transitions.get(nearest_experiment)						//get transitions (4 values) of our experiment
			val transfer_sequence = transfer_table.get(state).get(transition.SOURCE_)		//get transfer_sequence (Befehlsreihenfolge) of experiment
			for(i : transfer_sequence) sul.step(i)		//Navigiere zu dem State (anhand der transfer_sequence), von dem aus eine Transition gemessen werden muss
														//Führe einzelne Befehle innerhalb des systems aus / mache nötige Transitions			
			nearest_experiment.measure					//Nehme einen Messwert der Transition auf: Berechne sprt des momentanen Experiments 
														//proc_to_measure.apply	Inhalt von [] aus Codezeile 121 wird ausgeführt		
					
			
			println('''*******************************************************************''')
			println('''Transfer Sequence: «transfer_sequence»''')
			println('''Current Transition: «transition»''')
			state = transition.TARGET_					//state is now: end state
		}
		
		
		for(e : experiments){
			var regression_line = e.calculateResult								//result = getResult, result is a regression line
			if (e.checkHypothesis == true) {									// if h_alt or no hyp accepted - NEWWW
				val data_points = e.dataPoints									// get data points
				regression_line = RegressionLine.create(data_points, true)		//create LR with data_points			
			}
			val transition = exp_to_transitions.get(e)	
			
			// print to csv File
			var name = "data_"
			var cur_source = transition.SOURCE_
			var cur_input = transition.INPUT_ as String
			var filename = name + cur_source + cur_input
			println('''filename:«filename»''' )
			CalculationUtils.DataSeriesToFile(e.dataPoints, filename)		// input + source im namen hinzufügen
			
			println('''Transition: «transition»''')
			println('''«regression_line»''')
		}
		
		return exp_to_transitions
	}
	
	
}
