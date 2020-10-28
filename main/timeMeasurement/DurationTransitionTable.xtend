package org.avl.statemachines.stmbot.timeMeasurement

import java.util.Map
import net.automatalib.automata.transout.MealyMachine
import net.automatalib.words.Alphabet
import org.avl.statemachines.stmbot.output.TransitionTable
import org.avl.statemachines.stmbot.utils.TransitionData
import org.eclipse.xtext.xbase.lib.Functions.Function1

class DurationTransitionTable <S,I,T,O,H extends Hypothesis> extends TransitionTable<S,I,T,O>{
	
	Map<SPRTExperiment<H>, TransitionData<S, I, O>> exp_to_transition_
	Function1<H,String> f_cell_
	
	Function1<SPRTExperiment<H>, H> f_result_
	
	new(MealyMachine<S, I, T, O> machine, Alphabet<I> alphabet, Map<SPRTExperiment<H>,TransitionData<S,I,O>> exp_to_transition, Function1<H,String> f_cell, Function1<SPRTExperiment<H>,H> f_result) {
		super(machine, alphabet)
		this.exp_to_transition_ = exp_to_transition
		this.f_cell_ = f_cell
		this.f_result_ = f_result
	}
	
	override operation(S state, I input) {
		val experiment = exp_to_transition_.keySet.findFirst[ e|
			val transition = exp_to_transition_.get(e)
			transition.SOURCE_.equals(state) && transition.INPUT_.equals(input)
		]
		if (experiment === null) return ""		//=== typensichere Abfrage
//		val result = experiment.result
		
		val result = f_result_.apply(experiment)
		
		if (result === null) return ""
		
		return f_cell_.apply(result)				
	}	
}