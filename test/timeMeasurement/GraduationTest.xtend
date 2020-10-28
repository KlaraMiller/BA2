package org.avl.statemachines.stmbot.timeMeasurement

import junit.framework.TestCase
import net.automatalib.automata.transout.MealyMachine
import org.avl.statemachines.stmbot.algorithms.noReset.OptimizedHW
import org.avl.statemachines.stmbot.learning.LearningProcessBuilder
import org.avl.statemachines.stmbot.utils.TimeTestSUL01

import static extension org.avl.common.businesslogic.utils.JavaFXUtils.*
import static extension org.avl.statemachines.stmbot.utils.STMTestUtils.*
import static extension org.avl.statemachines.stmbot.utils.STMUtils.*
import org.avl.statemachines.stmbot.output.StateDiffTransitionTable
import org.avl.statemachines.stmbot.output.CSVTransitionTable
import org.avl.statemachines.stmbot.utils.STMUtils
import org.eclipse.xtext.xbase.lib.Procedures.Procedure0

// stm learning routine
class GraduationTest extends TestCase{
	def instantiationTest(){
		val sul = new TimeTestSUL01()
		val alphabet = sul.alphabet
		
//		val h = #["Dideldum"].asWord
//		val W = #["Dideldei".toWord]
//
//		val algo = new OptimizedHW(sul, alphabet,h,W,#{})
//		val lpb = new LearningProcessBuilder
//		lpb.algorithmProperty.bind(algo.toProperty)
//		lpb.alphabetProperty.bind(alphabet.toProperty)
//
//		val lp = lpb.build
//		val mm = lp.runSynchronized as MealyMachine<Integer,String,Object,String>			//angelernte stm
//		sul.reset()
		
		val tt = new StateDiffTransitionTable(sul, alphabet)
		tt.build
		val caption = "GradStm"
		new CSVTransitionTable(caption + "Full.csv", tt, caption).save
		
		val exp_to_transitions = TimeMeasurement.checkSTMDrift(sul, alphabet, sul, 0.01, 15, true, 0.01)	//good max_slope: 0.01
		
		
		val dt_offset = new DurationTransitionTable(sul, alphabet, exp_to_transitions, [r|r.OFFSET.toString.replace(".",",")],[e|e.calculateResult])	//Add Offset (Transition) into Transition
		dt_offset.build
		new CSVTransitionTable(caption + "Offset.csv", dt_offset, caption).save
		
		val dt_stddev = new DurationTransitionTable(sul, alphabet, exp_to_transitions, [r|r.STD_DEV.toString.replace(".",",")],[e|e.calculateResult])	//Add Standard Deviation (Transition) into Transition
		dt_stddev.build
		new CSVTransitionTable(caption + "Standarddev.csv", dt_stddev, caption).save
		
		val dt_slope = new DurationTransitionTable(sul, alphabet, exp_to_transitions, [r|r.SLOPE.toString.replace(".",",")],[e|e.calculateResult])	//Add Slope (Transition) into Transition
		dt_slope.build
		new CSVTransitionTable(caption + "Slope.csv", dt_slope, caption).save

	}
	
	def OutputTest () {		
		val sul = new TimeTestSUL01() 
		sul.showSolution
	}
	
	
	def specificTransTest() {
		
		val sul = new TimeTestSUL01()
		val alphabet = sul.alphabet
		
		val transfer_table = STMUtils.getTransferTable(sul, alphabet)
		
		val source = 6
		val input = "Dideldum"
//		val input = "Dideldei"
		
		sul.reset
		val sequence = transfer_table.get(sul.initialState).get(sul.getSuccessor(source, input))		//Get sequence to go from initial to source state from where you want to measure
		println(sequence)	
		
		for (s : sequence) println(sul.step(s))			//Go to source state from where to measure the transition
		
		val proc_to_measure = [					// write procedure in variable; .apply happens in measure() which is called in checkMaxDrift()
			println('''measuring:''')			
			sul.step(input)						// measure transition (step) from source (to target) state with defined input						
		] as Procedure0
		val proc_to_prepare = [					// proc_to_prepare is a process that gets the state machine back to the state, we want to measure
			val sequence2 = transfer_table.get(sul.getSuccessor(source, input)).get(source)		//go to start state
			println('''Transfer Sequence: «sequence2»''')
			for (s : sequence2) sul.step(s)		//go the steps
			] as Procedure0
		
		//measure (calculate regression line)
		val regression_line = TimeMeasurement.checkMaxDrift(proc_to_measure, proc_to_prepare, 0.0006, 0.01, 5, true)	//max_slope 0.1e-3, p_error, min_iter
		
		println(regression_line)
		
	}
}