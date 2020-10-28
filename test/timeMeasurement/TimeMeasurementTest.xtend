package org.avl.statemachines.stmbot.timeMeasurement

import junit.framework.TestCase
import org.avl.statemachines.stmbot.testdata.TBSimu
import org.avl.statemachines.stmbot.utils.FileUtils
import org.eclipse.xtext.xbase.lib.Procedures.Procedure0
import org.avl.statemachines.stmbot.algorithms.noReset.OptimizedHW
import org.avl.statemachines.stmbot.learning.LearningProcessBuilder
import net.automatalib.automata.transout.MealyMachine
import org.avl.statemachines.stmbot.output.StateDiffTransitionTable
import org.avl.statemachines.stmbot.output.CSVTransitionTable
import static extension org.avl.common.businesslogic.utils.JavaFXUtils.*
import static extension org.avl.statemachines.stmbot.utils.STMTestUtils.*
import static extension org.avl.statemachines.stmbot.utils.STMUtils.*
import net.automatalib.words.impl.Alphabets
import org.avl.statemachines.stmbot.testdata.TestAutomata
import org.avl.statemachines.stmbot.utils.StringStringWrapperSUL
import org.avl.statemachines.stmbot.connection.tcp.TCPConnection
import org.avl.statemachines.stmbot.connection.ak.ConcreteAKConnection
import org.avl.statemachines.stmbot.learning.ak.WaitPlugin
import net.automatalib.words.Alphabet
import java.util.Map
import org.avl.statemachines.stmbot.utils.TransitionData
import org.eclipse.xtext.xbase.lib.Functions.Function1

class TimeMeasurementTest extends TestCase {
	static final Function1<SPRTExperiment<RegressionLine>,RegressionLine> EXP_TO_REGRESSION_LINE = [SPRTExperiment<RegressionLine> e |
			if(e.checkHypothesis) return RegressionLine.create(e.dataPoints, true)
			return e.calculateResult
		]
	
	
	/**
	* Simulates waiting times
	*/
	def basicSimulatorTest() {
		val simulator = new TimeSimulator(3,1,0.1,true)		//(offset, slope, std_dev, indexed)
		for(i:0..<5){		
			simulator.run()
		}
	}	
	
	/**
	 * Measures (simulated) waiting times
	 */
	def singleMeasurementTest() {
		val simulator = new TimeSimulator(5,0,0,true)			//create a simulator object
		//create proc_to_measure object, 'simulator.run()' will be activated, when .apply is executed -> next line, in measure()
		val proc_to_measure = [simulator.run()] as Procedure0
		var str = ""
		for(i:0..<5){		//250x5sec = 20,8min //1h = 750
			val measured_time = TimeMeasurement.measure(proc_to_measure)	//call method measure() to measure/count how long process took
			System.out.println("Measured " + measured_time + " seconds")
			str += measured_time + "\n"
		}
		FileUtils.toFile(str.replace('.',','),"output/WartezeitMessung.csv")				
	}
	
	/**
	 * Test to measure a (simulated) time series
	 * Prints 
	 */
	def seriesMeasurementTest() {
		System.out.println("Series Measurement Test")
		val simulator = new TimeSimulator(1,1,0.1,true)						
		val proc_to_measure = [simulator.run()] as Procedure0		
		val measured_time_series = TimeMeasurement.measureSeries(proc_to_measure, 5)	//
		System.out.println("Measured series (index, time, y): " + measured_time_series)	
		
		//Code Examples to get specific data from the series or a data point:
		System.out.println(measured_time_series.get(0))		//Ausgabe eines Datenpunkts (0-4)
		//Get specific data value from a data point:
		measured_time_series.head		//erster Wert
		measured_time_series.last		//letzter Wert
		var specific_index_ = measured_time_series.get(1).INDEX
		var trash = measured_time_series.get(1).T
		trash = measured_time_series.get(1).Y
		//Get indices of all data points
		var indices = measured_time_series.map[INDEX]		//implicit
		indices = measured_time_series.map[d|d.INDEX]		//explicit [Argument|Body der Funktion]
		//Get time values (t_) of all data points
		var time_values = measured_time_series.map[T]
		System.out.println(time_values)
	}
	
	/**
	 * Test: Building a regression line from simulated data and calculating error
	 */
	def linearRegressionTestSim() {
		val indexed = true
		
		val simulator = new TimeSimulator(1,0.1,0.1,indexed)		//echte Zufallsvariablen
		val proc_to_measure = [simulator.run()] as Procedure0	
		val measured_time_series = TimeMeasurement.measureSeries(proc_to_measure, 10)		
		val regression_line = RegressionLine.create(measured_time_series, indexed)		//Schätzung der Zufallsvariablen durch Berechnung einer Regressionsgeraden
		
		val err_offset = Math.abs(regression_line.OFFSET - simulator.OFFSET)
		val err_slope = Math.abs(regression_line.SLOPE - simulator.SLOPE)
		val err_std_dev = Math.abs(regression_line.STD_DEV - simulator.STD_DEV)
		
		val p_err_offset = err_offset / simulator.OFFSET * 100
		val p_err_slope = err_slope / simulator.SLOPE * 100
		val p_err_std_dev = err_std_dev / simulator.STD_DEV * 100
		
		//print
		println("Linear Regression Test")
		println('''a:		«regression_line.OFFSET» |«err_offset»| «p_err_offset»%''')
		println('''b:		«regression_line.SLOPE» |«err_slope»|«p_err_slope»%''')
		println('''Std:		«regression_line.STD_DEV» |«err_std_dev»| «p_err_std_dev»%''')	
		for(d : measured_time_series){
			println('''«d.INDEX»; «d.T»; «d.Y»''')
		}
	}	
	
	/**
	 * Test: Building a regression line from real data
	 */
	def linearRegressionTestReal() {
		val indexed = true
		val builder = TBSimu.getSULBuilder(TBSimu.AVL740, 15000, false)
		val builder_result = builder.build		
		val avl740 = builder_result.SUL
		val simulator = new TimeSimulator(0,0,0,indexed)		//slope = 0.1
		val proc_to_measure = [
			avl740.waitForCondition[!busy]
			simulator.run					// add fake slope
		] as Procedure0
		val proc_to_prepare = [
			avl740.waitForCondition[!busy]
			println(avl740.step("SREM"))
			println(avl740.step("SRES"))
			avl740.waitForCondition[!busy]
			println(avl740.step("SREM"))
			println(avl740.step("STBY"))
		] as Procedure0
			
//		avl740.waitForCondition[!busy]
		
		val measured_time_series = TimeMeasurement.measureSeries(proc_to_measure, proc_to_prepare, 20)
		val regression_line = RegressionLine.create(measured_time_series, indexed)
		
		CalculationUtils.DataSeriesToFile(measured_time_series, "data_series")
		println('''«regression_line»''')
	}		
	
	/**
	 * Test: Generating and a list of data points from real data and print to csv File
	 */
	def dataGenerationTest () {						//almost the same as linearRegressionTestReal()
		val indexed = true
		val builder = TBSimu.getSULBuilder(TBSimu.AVL740, 15000, false)
		val builder_result = builder.build		
		val avl740 = builder_result.SUL
		val proc_to_measure = [
			avl740.waitForCondition[!busy]
		] as Procedure0
		val proc_to_prepare = [
			avl740.waitForCondition[!busy]
			println(avl740.step("SREM"))
			println(avl740.step("SRES"))
			avl740.waitForCondition[!busy]
			println(avl740.step("SREM"))
			println(avl740.step("STBY"))
		] as Procedure0
			
//		avl740.waitForCondition[!busy]
		
		val measured_time_series = TimeMeasurement.measureSeries(proc_to_measure, proc_to_prepare, 1000)			//oft messen
		val regression_line = RegressionLine.create(measured_time_series, indexed)
		println('''«regression_line»''')

		CalculationUtils.DataSeriesToFile(measured_time_series, "data_series")		
	}
	
	/**
	 * Test to determine if measured data has a drift (slope) or not
	 * @prints the regression line, that represents the data best
	 */
	def sprtTest() {
		val indexed = true
		val builder = TBSimu.getSULBuilder(TBSimu.AVL740, 15000, false)		// connect to device 
		val builder_result = builder.build		
		val avl740 = builder_result.SUL
		val simulator = new TimeSimulator(0,0.1,0,indexed)					// create simulator	//offset, slope, std_dev, indexed
		val proc_to_measure = [					// write procedure in variable; .apply happens in measure() which is called in checkMaxDrift()
			avl740.waitForCondition[!busy]
			simulator.run													// to simulate a slope: add fake slope
		] as Procedure0
		val proc_to_prepare = [					// proc_to_prepare is a process that gets the statemachine back to the state, we want to measure
			avl740.waitForCondition[!busy]
			println(avl740.step("SREM"))
			println(avl740.step("SRES"))
			avl740.waitForCondition[!busy]
			println(avl740.step("SREM"))
			println(avl740.step("STBY"))
		] as Procedure0
		
		//measure (calculate regression line)
		val regression_line = TimeMeasurement.checkMaxDrift(proc_to_measure, proc_to_prepare, 0.1, 0.01, 5, indexed)	//max_slope 0.1e-3, p_error, min_iter
		
		println('''«regression_line»''')		
	}
	
	def fileWriteTest() {
		FileUtils.toFile('''hi''', 'hello.txt')
	}
	
	/**
	 * Test to determine if measured data sets have a drift or not
	 * Takes one measurement at a time and program can do something else in the mean time
	 * Uses SPRTExperiment
	 * @prints the regression line, that represents the data best
	 */
	def sprtTest2() {
		val indexed = true
		val builder = TBSimu.getSULBuilder(TBSimu.AVL740, 15000, false)		// connect to device 
		val builder_result = builder.build		
		val avl740 = builder_result.SUL
		val simulator = new TimeSimulator(0,0.1,0,indexed)					// create simulator
		
		val proc_to_measure = [					// write procedure in variable; .apply happens in measure() which is called in checkMaxDrift()
			avl740.waitForCondition[!busy]
			simulator.run													// to simulate a slope: add fake slope
		] as Procedure0
		val proc_to_prepare = [					// proc_to_prepare is a process that gets the statemachine back to the state, we want to measure
			avl740.waitForCondition[!busy]
			println(avl740.step("SREM"))
			println(avl740.step("SRES"))
			avl740.waitForCondition[!busy]
			println(avl740.step("SREM"))
			println(avl740.step("STBY"))
		] as Procedure0
		
		//create function of DataSeries
		val h0 = [DataSeries data_points|RegressionLine.create(data_points, 0, indexed)]		//repräsentiert h0, dass Datenpunkte auf Regressionline ohne drift liegen		//[] function from data series of regression line //line without drift		
		val h1 = [DataSeries data_points|RegressionLine.create(data_points, 0.01, indexed)]		//repräsentiert h1, dass Datenpunkte auf Regressionline mit drift liegen	//(data_points, max_slope (1e-5), indexed)
		
		val experiment1 = new SPRTExperiment(proc_to_measure, 0.01, 1, indexed, h0, h1)	//what to measure, Randbedingungen and hypotheses	//h0 and h1 are regression lines	
		
		var cnt = 1
				
		// magic. measures one data point till one hypothesis is accepted
		while(!experiment1.finished) {
			proc_to_prepare.apply
			experiment1.measure			// measures 1 data point (1 transition)
			// anything could happen here while measuring
		}
		
		CalculationUtils.DataSeriesToFile(experiment1.getDataPoints, "data_output")		//Print list of data points in csv file
				
		// print LR with calculated slope		
		var regression_line = experiment1.calculateResult							//result = getResult, result is a regression line
		if (experiment1.checkHypothesis == true) {									// if h_alt or no hyp accepted - NEWWW
			val data_points = experiment1.dataPoints									// get data points
			regression_line = RegressionLine.create(data_points, true)		//create LR with data_points			
		}
		println('''«regression_line»''')	
	}
	
	
	/**
	 * Check all transitions of state machine if one or more have a drift over time or not
	 * Test is done on a 'system under learning' (sul) and a model of that, in form of a state machine (mm)
	 */
	def sprtTest3(){
		val connection = TBSimu.AVL740
		val timeout = 15000
		val builder = TBSimu.getSULBuilder(connection,timeout,false)
		val result = builder.build		
		
		val mm = TestAutomata.small740		// erlerntes Modell, ohne Timingwerte ('Landkarte')
		val sul = new StringStringWrapperSUL(result.SUL,[x|x])		//'Territorium'
		sul.step("WAIA")
		sul.step("SRES")
		sul.step("SREM")

		TimeMeasurement.checkSTMDrift(mm, mm.inputAlphabet, sul, 0.01, 5, true, 0.1)
		
	}
	
		def sprtTest4(){
//		val connection = TBSimu.AVL740
//		val connection = TBSimu.AVL415S	
		
		val tcp = new TCPConnection("localhost", 1740, 500, #[3])	//Port 1+Device number = AVL415
		val connection = new ConcreteAKConnection(tcp)
		connection.open		
		
		val timeout = 15000
		val builder = TBSimu.getSULBuilder(connection,timeout,false)
		val result = builder.build	
		val srt = result.SUL.stateRetrievalProvider.telegrams.map[code].asWord		//srt = state retreaval telegram = telegramme, deren Antworten uns einen State geben
			
//		val alphabet = Alphabets.fromList(#["SPUL","SRDY","WAIA"])		//Inputs for AVL415s	//nimmt nur bestimmte Befehle der Liste
//		val alphabet = Alphabets.fromList(#["SPUL","SRDY","WAIA","SASB","SFPF","SKOR","SLEC"/*,"SMES","SMKA","SMRE","SVOP"*/]) //works
//		val alphabet = Alphabets.fromList(#["SVOP"]) // works
//		val alphabet = Alphabets.fromList(#["SMES","SMKA","SMRE","WAIA"]) // funktioniereth
//		val alphabet = Alphabets.fromList(#["SPUL","SRDY","WAIA","SASB","SFPF","SKOR","SLEC",/*"SMES","SMKA"/*,*/"SMRE","SVOP"]) // funktioniert
//		val alphabet = Alphabets.fromList(#["SPUL","SRDY","WAIA","SASB","SFPF","SKOR","SLEC", "SMKA","SMRE","SVOP"]) // funktioniert
		val alphabet = Alphabets.fromList(#["SPUL","SRDY","WAIA","SASB","SFPF","SKOR","SLEC", "SMKA","SMRE","SVOP", "SEX1", "SEX2", "SPSA","SPSE","SMAN","SREM"])	//415s
		
//		val alphabet = Alphabets.fromList(#["SMES","SMKA"]) // worketh not
//		val alphabet = Alphabets.fromList(#["SMES","SMKA","SMRE"/*,"SPUL","SRDY","SVOP"*/]) // fails
//		val alphabet = Alphabets.fromList(#["SPAU","STBY","WAIA"])		//Inputs for AVL470
//		val alphabet = result.alphabet
		
		val h = #["WAIA","SREM"].asWord.append(srt)		//Parameter für STM-Algo	//AVL415s
		val W = #[srt]
		val s = srt.toSet
//		val h = #["WAIA","SREM","ASTA"].asWord		//Parameter für STM-Algo	//AVL740
//		val W = #["ASTA".toWord]
//		val s = #{"ASTA"}
		val algo = new OptimizedHW(result.SUL, alphabet,h,W,s)		//neuer Algo wird angelegt
		val lpb = new LearningProcessBuilder						//Algo wird ersetzt durch einen neuen
		lpb.algorithmProperty.bind(algo.toProperty)
		lpb.alphabetProperty.bind(alphabet.toProperty)

		val lp = lpb.build
		val mm = lp.runSynchronized as MealyMachine<Integer,String,Object,String>		
//		val mm = TestAutomata.small740		// erlerntes Modell, ohne Timingwerte ('Landkarte')

		val tt = new StateDiffTransitionTable(mm, alphabet)
		tt.build
		val caption = builder.closestIdentification.deviceName
		new CSVTransitionTable(caption + "Full.csv", tt, caption).save
		
		val sul = new StringStringWrapperSUL(result.SUL,[x|x])		//'Territorium'
		sul.step("WAIA")
		sul.step("SRES")
		sul.step("SREM")

		val exp_to_transitions = TimeMeasurement.checkSTMDrift(mm, alphabet, sul, 0.01, 15, true, 0.01)	//good max_slope: 0.01
		 		
		
		val dt_offset = new DurationTransitionTable(mm, alphabet, exp_to_transitions, [r|r.OFFSET.toString.replace(".",",")], EXP_TO_REGRESSION_LINE)	//Add Offset (Transition) into Transition
		dt_offset.build
		new CSVTransitionTable(caption + "Offset.csv", dt_offset, caption).save
		
		val dt_stddev = new DurationTransitionTable(mm, alphabet, exp_to_transitions, [r|r.STD_DEV.toString.replace(".",",")], EXP_TO_REGRESSION_LINE)	//Add Standard Deviation (Transition) into Transition
		dt_stddev.build
		new CSVTransitionTable(caption + "Standarddev.csv", dt_stddev, caption).save
		
		val dt_slope = new DurationTransitionTable(mm, alphabet, exp_to_transitions, [r|r.SLOPE.toString.replace(".",",")], EXP_TO_REGRESSION_LINE)	//Add Slope (Transition) into Transition
		dt_slope.build
		new CSVTransitionTable(caption + "Slope.csv", dt_slope, caption).save
			
	}	
	
		/**
		 * Check all transitions of state machine if one or more have a drift over time or not
		 * Connect to TBsimu (740, 415s), circuit board (740) or real device (415s)
		 * Test is done on a 'system under learning' (sul) and a model of that, in form of a state machine (mm)
		 */	
		def sprtTestAll(){
//		val connection = TBSimu.AVL740
//		val connection = TBSimu.AVL415S	
		
		// AVL740
//		val tcp = new TCPConnection("localhost", 1740, 10000, #[3])			//AVL740 TBSimu, - Port Forward Nr: 2 
//		val tcp = new TCPConnection("atgrzsi508850", 2740, 10000, #[3])		//AVL740 Circuit Board 		//timeout => in case of no response 

		// AVL415s
//		val tcp = new TCPConnection("localhost", 1415, 10000, #[3])			//AVL415s TBSimu  (instead of Circuit Board)
		val tcp = new TCPConnection("atgrzsi508850", 2415, 10000, #[3])		//AVL415s Real Device 
		
		// Establish Connection
		val connection = new ConcreteAKConnection(tcp, 3000)		//idle_time for tcp connection
		connection.open		

		val timeout = 60000		//maximal wait timeout
		val builder = TBSimu.getSULBuilder(connection,timeout,false)
		val result = builder.build	
		
		val srt_list = result.SUL.stateRetrievalProvider.telegrams
		srt_list.removeAll(srt_list.filter["ASTA".equals(code)])
		val srt = srt_list.map[code].asWord		//srt = state retreaval telegram = telegramme, deren Antworten uns einen State geben
		
		val alphabet = Alphabets.fromList(#["SPUL","SRDY","WAIA","SASB","SFPF","SKOR","SLEC", "SMKA","SMRE","SVOP", "SEX1", "SEX2", "SPSA","SPSE","SMAN","SREM"])	//415s TBSimu + Echtgerät
//		val alphabet = Alphabets.fromList(#["SDRF", "SDRW", "SFIF", "SFIW", "SMAN", "SMES", "SPAU", "SREM", "SVNT", "WAIA", "STBY"]) //working for 740 circuit board + TBSimu
//		val alphabet = Alphabets.fromList(#["SPAU", "STBY", "WAIA"]) 	//Test sequence for debugging
		
//		val alphabet = Alphabets.fromList(#["SPAU","STBY","WAIA"])		//Inputs for AVL470
//		val alphabet = result.alphabet
		
		val h = #["WAIA","SREM"].asWord.append(srt)		//Parameter für STM-Algo	//AVL415s + AVL740
		val W = #[srt]
		val s = srt.toSet
//		val h = #["WAIA","SREM","ASTA"].asWord		//Parameter für STM-Algo	//AVL740
//		val W = #["ASTA".toWord]
//		val s = #{"ASTA"}

		result.SUL.addPlugin(new WaitPlugin(result.SUL))		// waits everytime before a state
		
		val sul = new StringStringWrapperSUL(result.SUL,[x|x])		//'Territorium'
//		sul.step("WAIA")

//		sul.step("ASTZ")
//		sul.step("SMAN")
//		sul.step("SMAN")
//		Thread.sleep(2000)
//		sul.step("ASTZ")
//		sul.step("SREM")
//		Thread.sleep(2000)
//		sul.step("ASTZ")
//		sul.step("SMAN")
//		sul.step("ASTZ")
//		sul.step("SREM")
//		sul.step("ASTZ")		
//		val i = 1/0
	
		sul.step("WAIA")
		sul.step("SREM")	
		
		val algo = new OptimizedHW(result.SUL, alphabet,h,W,s)		//neuer Algo wird angelegt
		val lpb = new LearningProcessBuilder						//Algo wird ersetzt durch einen neuen
		lpb.algorithmProperty.bind(algo.toProperty)
		lpb.alphabetProperty.bind(alphabet.toProperty)

		val lp = lpb.build
		val mm = lp.runSynchronized as MealyMachine<Integer,String,Object,String>		
//		val mm = TestAutomata.small740		// erlerntes Modell, ohne Timingwerte ('Landkarte')
		
		val caption = builder.closestIdentification.deviceName
		writeToCSV(mm, alphabet, null, caption+"Pre")

		val tt = new StateDiffTransitionTable(mm, alphabet)
		tt.build
		
		new CSVTransitionTable(caption + "Full.csv", tt, caption).save
		
//		val sul = new StringStringWrapperSUL(result.SUL,[x|x])
		sul.step("WAIA")
		sul.step("SREM")

		val exp_to_transitions = TimeMeasurement.checkSTMDrift(mm, alphabet, sul, 0.01, 15, true, 0.01)	//good max_slope: 0.01
		
		writeToCSV(mm, alphabet, exp_to_transitions, caption+"Post")
				
		
		val dt_offset = new DurationTransitionTable(mm, alphabet, exp_to_transitions, [r|r.OFFSET.toString.replace(".",",")], EXP_TO_REGRESSION_LINE)	//Add Offset (Transition) into Transition
		dt_offset.build
		new CSVTransitionTable(caption + "Offset.csv", dt_offset, caption).save
		
		val dt_stddev = new DurationTransitionTable(mm, alphabet, exp_to_transitions, [r|r.STD_DEV.toString.replace(".",",")], EXP_TO_REGRESSION_LINE)	//Add Standard Deviation (Transition) into Transition
		dt_stddev.build
		new CSVTransitionTable(caption + "Standarddev.csv", dt_stddev, caption).save
		
		val dt_slope = new DurationTransitionTable(mm, alphabet, exp_to_transitions, [r|r.SLOPE.toString.replace(".",",")], EXP_TO_REGRESSION_LINE)	//Add Slope (Transition) into Transition
		dt_slope.build
		new CSVTransitionTable(caption + "Slope.csv", dt_slope, caption).save
	}
	

	/**
	 * Check one specific transition of state machine (TBSimu or Circuit Board) and generate a lot of data points (for future probability density function)
	 */	
	def singleTransitionTest415s(){				
			
		// ESTABLISH CONNECTION	TO CircuitBoard or TBSimu
		// Build Connection
		val tcp = new TCPConnection("atgrzsi508850", 2415, 10000, #[3])		//AVL415s Real Device 
//		val tcp = new TCPConnection("localhost", 1415, 10000, #[3])			//TBSimu AVL415s 
		val connection = new ConcreteAKConnection(tcp, 1000) 
		connection.open		

		val timeout = 60000		//maximal wait timeout
		val builder = TBSimu.getSULBuilder(connection,timeout,false)
		val result = builder.build	
		val srt_list = result.SUL.stateRetrievalProvider.telegrams
		srt_list.removeAll(srt_list.filter["ASTA".equals(code)])
		val avl415 = result.SUL			//avl740 or avl415s

		// DEBUG
//		println(device.step("SRES"))
//		val i = 1/0
//		println(device.step("SEX2"))
//		println(device.step("SLEC"))
//		println(device.step("SMAN"))
//		println(device.step("WAIA"))
		
		// Inputs to measure a WAIA transition
		val proc_to_measure = [					// write procedure in variable; .apply happens in measure() which is called in checkMaxDrift()
			println(avl415.step("WAIA"))												// to simulate a slope: add fake slope
		] as Procedure0
		val proc_to_prepare = [					// proc_to_prepare is a process that gets the state machine back to the state, we want to measure
			println(avl415.step("SREM"))
//			while(!avl415.pollCurrentState.toString.contains("SGTS")) println(avl415.step("SLEC"))	//For TBSimu necessary
			println(avl415.step("SLEC"))
			println(avl415.step("SMAN"))
		] as Procedure0		
		
		
		// Inputs to measure an other transition
//		val proc_to_measure = [					// write procedure in variable; .apply happens in measure() which is called in checkMaxDrift()												// to simulate a slope: add fake slope
//		] as Procedure0
//		val proc_to_prepare = [					// proc_to_prepare is a process that gets the state machine back to the state, we want to measure
//		] as Procedure0	
				
		// Measure lots of data points
		val measured_time_series = TimeMeasurement.measureSeries(proc_to_measure, proc_to_prepare, 1000)			//oft messen
		CalculationUtils.DataSeriesToFile(measured_time_series, "415s_data_series")	
		
		// Calculate Regression Line of measured data
		val regression_line = RegressionLine.create(measured_time_series, true)	
		println('''«regression_line»''')
	}


	/**
	 * Check one specific transition of state machine (TBSimu or Circuit Board) and generate a lot of data points (for future probability density function)
	 */	
	def singleTransitionTest740(){				
			
		// ESTABLISH CONNECTION	to CircuitBoard or TBSimu
//		val tcp = new TCPConnection("atgrzsi508850", 2740, 10000, #[3])		//Circuit Board AVL740		//10 sec timeout => in case of no response 
		val tcp = new TCPConnection("localhost", 1740, 10000, #[3])			//TBSimu AVL740 
		val connection = new ConcreteAKConnection(tcp, 1000) 
		connection.open		

		val timeout = 60000		//maximal wait timeout
		val builder = TBSimu.getSULBuilder(connection,timeout,false)
		val result = builder.build	
		val avl740 = result.SUL			//avl740 or avl415s

		// Debug
		//is venting state timed? yes: cz there is a state change while WAIA is sent
//		println(avl740.step("WAIA"))
//		avl740.waitForCondition[!busy]		//step 
//		println(avl740.step("SVNT"))
//		println(avl740.step("WAIA"))
//		val i = 1/0		
			
		avl740.waitForCondition[!busy]
		println(avl740.step("SRES"))
		println(avl740.step("SREM"))		
		avl740.waitForCondition[!busy]
		println(avl740.step("STBY"))	
		avl740.waitForCondition[!busy]
		println(avl740.step("WAIA"))	
				
		// Inputs for 415s - to measure specific transition - Source: Pause/Operator/Ready/Not Active; Input: STBY; Target: Standby/Operator/Busy/Not Active
		val proc_to_measure = [
			avl740.waitForCondition[!busy]		//misst busy, falls es eines gibt
			println(avl740.step("WAIA"))
		] as Procedure0
		val proc_to_prepare = [
			println(avl740.step("SVNT"))
		] as Procedure0
		
		
		// Measure lots of data points
		val measured_time_series = TimeMeasurement.measureSeries(proc_to_measure, proc_to_prepare, 1000)			//oft messen
		CalculationUtils.DataSeriesToFile(measured_time_series, "740_data_series")	
		
		// Calculate Regression Line of measured data
		val regression_line = RegressionLine.create(measured_time_series, true)	
		println('''«regression_line»''')
	}



	
	def <S,I,T,O,E> void writeToCSV(MealyMachine<S,I,T,O> mm, Alphabet<I> alphabet, Map<SPRTExperiment<RegressionLine>,TransitionData<S,I,O>> e2t, String path){
		var out = ""
		for(s : mm.states){
			out += s + "\n"
			for( i : alphabet){
				out += '''«s»;«i»;«mm.getOutput(s,i)»;«mm.getSuccessor(s,i)»;'''
				if(e2t !== null){																			// experiment to transition map
					val td = e2t.values.findFirst[SOURCE_.equals(s) && INPUT_.equals(i)]
					val exp = e2t.keySet.findFirst[e|td.equals(e2t.get(e))]
					val rl = if(exp.checkHypothesis) RegressionLine.create(exp.dataPoints, true) else exp.calculateResult
					
					out += '''«rl.OFFSET»;«rl.SLOPE»;«rl.STD_DEV»;'''.toString.replace(".",",")
				}
				out += "\n"
			}
		}
		FileUtils.toFile(out, path + ".csv")
	}
}