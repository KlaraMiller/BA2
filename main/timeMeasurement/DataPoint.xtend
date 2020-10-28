package org.avl.statemachines.stmbot.timeMeasurement

class DataPoint {
	
	public final int INDEX			//statt 'get/set' Methoden -> final -> können nur 1x gesetzt werden (im Konstr)
	public final double T
	public final double Y
	
	new(int index, double t, double y) {
		INDEX = index
		T = t
		Y = y		
	}
	
	override toString() {
//		return "(" + index_ + ", " + t_ + ", " + y_+")"	//Java style
		return '''(«INDEX», «T», «Y»)'''				//Xtend style
//		'''(«index_», «t_», «y_»)'''					// fnzt auch ohne return
	}
	
}