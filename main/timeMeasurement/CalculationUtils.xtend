package org.avl.statemachines.stmbot.timeMeasurement

import org.avl.statemachines.stmbot.utils.FileUtils
import java.io.File

abstract class CalculationUtils {
	
	def static mean(int[] data_array_) {
		var sum = 0
		for(value : data_array_) {
			sum += value
		}
//		for(i:0..<data_array_.length) {
//			sum += data_array_.get(i);
//		}
		return (sum / data_array_.length)
	}	
	
	def static mean_double(double[] data_array_) {
		var double sum = 0
		for(value : data_array_) {
			sum += value
		}
		return (sum / data_array_.length)
	}	
	
	/**
	 * print data points of a data series to a csv file
	 */
	def static void DataSeriesToFile(DataSeries series, String filename) {				
		
		val file_extension = ".csv"		
		val txtout = '''
		index;t;y
		«FOR d : series»
		«d.INDEX»; «d.T»; «d.Y»
		«ENDFOR»
		'''
		//FileUtils.	//if file exists -> index++
		var new_file_name = makeNewFileName("output/", filename, file_extension)
		FileUtils.toFile(txtout.replace('.',','), new_file_name)
		println('''Data Series printed to: «new_file_name»''')
		
//		File newFile;
//		var index = 1;
//		var parent = "C:\\tmp"
//		var name = "Person";
//		while ((newFile = new File(parent, name + index)).exists()) {
//		    index++;	
	}	
		
	def static String makeNewFileName(String path, String name, String file_extension){
		if(!new File(path + name + file_extension).exists) return path + name + file_extension
		var count = 1
		while(new File(path + name + count + file_extension).exists) count++
		return path + name + count + file_extension
	}
	
	
	//	def static String makeNewFileName(String path, String name, String file_extension){
//		if(!(new File(path + name + file_extension).exists)) {
//			return path + name + file_extension
//		}
//		else {
//			var count = 1
//			while(new File(path + name + count + file_extension).exists) count++
//			return path + name + count + file_extension		
//		}
//	}
	
}