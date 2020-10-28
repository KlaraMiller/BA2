package org.avl.statemachines.stmbot.timeMeasurement

import java.util.ArrayList


class DataSeries extends ArrayList<DataPoint> {
	
	new () {
		super ()
	}
	
	new (DataSeries data) {
		super (data)
	}
	
		
	def getX (boolean indexed) {		
		return (if(indexed) this.map[INDEX] else this.map[T]).map[doubleValue]	//this bezieht sich auf Objekt, mit dem die Methode aufgerufen wird	
	}
	
}