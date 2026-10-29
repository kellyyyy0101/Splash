/*
 * Scratch Project Editor and Player
 * Copyright (C) 2014 Massachusetts Institute of Technology
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

// Primitives.as
// John Maloney, April 2010
//
// Miscellaneous primitives. Registers other primitive modules.
// Note: A few control structure primitives are implemented directly in Interpreter.as.

package primitives {
	import flash.utils.Dictionary;
	import blocks.*;
	import interpreter.*;
	import scratch.*;
	import ui.*;
	import ui.media.*;
	import ui.parts.*;
	import translation.Translator;
	import flash.utils.ByteArray;

	import com.adobe.utils.StringUtil;

	import flash.errors.IllegalOperationError;
	import flash.events.*;
	import flash.net.*;

	import mx.utils.URLUtil;

	import uiwidgets.DialogBox;

	import util.*;

public class Primitives {

	private var MaxCloneCount:int = 300;

	protected var app:Scratch;
	protected var interp:Interpreter;
	protected var stagePart:StagePart;
	private var counter:int;
	private var tempVars:Array = [{name:" ", value:"2"},];//empty at the start

	private var peerMeshCache:Object = {}; // Caches values received from other instances
	private const MESH_PORT:int = 14321;   // Port for mesh

	private var receiverConn:LocalConnection;
	private var senderConn:LocalConnection;
	private var instanceID:String;

	public function Primitives(app:Scratch, interpreter:Interpreter) {
		this.app = app;
		this.interp = interpreter;

	}

	private var activeListeningHubID:int = -1;

	
	

	public function addPrimsTo(primTable:Dictionary):void {
		// operators
		primTable["+"]				= function(b:*):* { return interp.numarg(b, 0) + interp.numarg(b, 1) };
		primTable["-"]				= function(b:*):* { return interp.numarg(b, 0) - interp.numarg(b, 1) };
		primTable["*"]				= function(b:*):* { return interp.numarg(b, 0) * interp.numarg(b, 1) };
		primTable["^"]				= function(b:*):* { return Math.pow(interp.numarg(b, 0), interp.numarg(b, 1)) };
		primTable["/"]				= function(b:*):* { return interp.numarg(b, 0) / interp.numarg(b, 1) };
		primTable["randomFrom:to:"]	= primRandom;
		primTable["<"]				= function(b:*):* { return compare(interp.arg(b, 0), interp.arg(b, 1)) < 0 };
		primTable["="]				= function(b:*):* { return compare(interp.arg(b, 0), interp.arg(b, 1)) == 0 };
		primTable[">"]				= function(b:*):* { return compare(interp.arg(b, 0), interp.arg(b, 1)) > 0 };
		primTable["&"]				= function(b:*):* { return interp.arg(b, 0) && interp.arg(b, 1) };
		primTable["|"]				= function(b:*):* { return interp.arg(b, 0) || interp.arg(b, 1) };
		primTable["not"]			= function(b:*):* { return !interp.arg(b, 0) };
		primTable["abs"]			= function(b:*):* { return Math.abs(interp.numarg(b, 0)) };
		primTable["sqrt"]			= function(b:*):* { return Math.sqrt(interp.numarg(b, 0)) };

		primTable["concatenate:with:"]	= function(b:*):* { return ("" + interp.arg(b, 0) + interp.arg(b, 1)).substr(0, 10240); };
		primTable["letter:of:"]			= primLetterOf;
		primTable["stringLength:"]		= function(b:*):* { return String(interp.arg(b, 0)).length };

		primTable["%"]					= primModulo;
		primTable["rounded"]			= function(b:*):* { return Math.round(interp.numarg(b, 0)) };
		primTable["computeFunction:of:"] = primMathFunction;

		// clone
		primTable["createCloneOf"]		= primCreateCloneOf;
		primTable["deleteClone"]		= primDeleteClone;
		primTable["whenCloned"]			= interp.primNoop;

		primTable["true"]			= function(b:*):* { return true };
		primTable["false"]			= function(b:*):* { return false };

		// testing (for development)
		primTable["NOOP"]				= interp.primNoop;
		primTable["COUNT"]				= function(b:*):* { return counter };
		primTable["INCR_COUNT"]			= function(b:*):* { counter++ };
		primTable["CLR_COUNT"]			= function(b:*):* { counter = 0 };

		primTable["booleanPredicate"]		= primBoolean;

		primTable["newlinechar"]		= function(b:*):* { return "\n" }; 

		primTable["getColourInput"]		= function(b:*):* { return interp.numarg(b, 0)};

		primTable["join:Triple:"]		=function(b:*):* { return ("" + interp.arg(b, 0) + interp.arg(b, 1) + interp.arg(b, 2)).substr(0, 10240); };
		primTable["if:then:else:"]		= primIfElse;
		primTable["if:then:bool:"]		= primIfElseBool;
		primTable["returnString"]		= function(b:*):* {return(interp.arg(b,0))};

		primTable["toggleTurbo"]		= primTurbo;//function(b:*):* { interp.turboMode = !interp.turboMode };
		primTable["setCloneLimit"]		= function(b:*):* { MaxCloneCount = interp.numarg(b, 0) };
		primTable["getCloneLimit"]		= function(b:*):* { return MaxCloneCount };

		primTable["tempVar"]			= primGetTempVar;
		primTable["createTempVar"]		= function(b:*):* { tempVars.push({name:interp.arg(b, 0), value:""}) };
		primTable["setTempVar"]			= primSetTempVar;
		primTable["changeTempVar"]			= primChangeTempVar;
		
		primTable["onlineStatus"]		= function(b:*):* {return true};

		primTable["randomJoke"]			= primRandomJoke

		primTable["randomPhrase"]		= function(b:*):* {return 0};

		primTable["execJs"]				= function(b:*):* {app.callJsFunction("execJs", interp.arg(b, 0))};

		primTable["fetchUrl"]			= function(b:*):* {
			function responseHandler(e:Event):void {
				if(e.type == Event.COMPLETE){
					b.response = loader.data;
				}else{
					b.response = '';
				}
				b.requestState = 2;
				b.requestLoader = null;
			}

			var loader:URLLoader = new URLLoader();
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, responseHandler);
			loader.addEventListener(IOErrorEvent.IO_ERROR, responseHandler);
			loader.addEventListener(Event.COMPLETE, responseHandler);

			b.requestState = 1;
			b.requestLoader = loader;

			var url:String = 'http://' + interp.arg(b,0);
			loader.load(new URLRequest(url));
			return(loader.data);
			}


		primTable["letters:to:of:"]		= primLettersBetween;
		//primTable["alterString"]		= primAlterString;
		primTable["caseSensitive"]		= function(b:*):Boolean { return (interp.arg(b, 0) == interp.arg(b, 1)) };
		primTable["asciiFor:"]			= function(b:*):* { return interp.arg(b, 0).charCodeAt(0) };
		primTable["ascii:asString"]		= function(b:*):* { return String.fromCharCode((interp.numarg(b, 0))) };
		primTable[":contains:"]			= function(b:*):Boolean {
				var a:* = interp.arg(b, 0);
				if(a.indexOf(interp.arg(b, 1)) >= 0){
					return true;
				} else {
					return false;
				}
			}
		primTable["times:isIn:"]		= function(b:*):* {
				var str:String = interp.arg(b, 1);
				var char:String = interp.arg(b, 0);

				function countOccurences(str:String, char:String):Number {
					var count:Number = 0;

					for(var i:Number=0; i < str.length; i++) {
						if (str.charAt(i) == char) {
							count++;
						}
					}
					return count;
				}

				return countOccurences(str, char);
		}
		primTable["replaceEvery"]		= function(b:*):* {
				var str:String = interp.arg(b, 1);
				var search:String = interp.arg(b, 0);
				var replace:String = interp.arg(b, 2);

				function strReplace(str:String, search:String, replace:String):String {
					return str.split(search).join(replace);
				}
				return strReplace(str, search, replace);
		}

		primTable["replaceBetween"]		= function(b:*):* {
				//First, grab the text between the two numbers
				var s:String = interp.arg(b, 2);
				var n1:int = interp.numarg(b, 0) - 1;
				var n2:int = interp.numarg(b, 1);
				if ((n1 < 0) || (n2 >= s.length)) return "";
				var sect:String = s.slice(n1, n2);
				//Then the find-and-replace tactic (FLAWED!!! Can replace two bits of identical text...)
				var str:String = interp.arg(b, 2);
				var search:String = sect;
				var replace:String = interp.arg(b, 3);

				function strReplace(str:String, search:String, replace:String):String {
					return str.split(search).join(replace);
				}
				return strReplace(str, search, replace);
		}
		primTable["repeat::times"]		= function(b:*):* {
				function repeatString(string:String, numTimes:uint):String {
					var output:String = "";
					for(var i:uint = 0; i < numTimes; i++)
					output += string;
					return output;
				}
				return repeatString(interp.arg(b, 0), interp.arg(b, 1));
		}
		new LooksPrims(app, interp).addPrimsTo(primTable);
		new MotionAndPenPrims(app, interp).addPrimsTo(primTable);
		new SoundPrims(app, interp).addPrimsTo(primTable);
		new VideoMotionPrims(app, interp).addPrimsTo(primTable);
		new SensorPrims(app, interp).addPrimsTo(primTable);
		addOtherPrims(primTable);
	}

	protected function addOtherPrims(primTable:Dictionary):void {
		new SensingPrims(app, interp).addPrimsTo(primTable);
		new ListPrims(app, interp).addPrimsTo(primTable);
	}

	private function primRandom(b:Block):Number {
		var n1:Number = interp.numarg(b, 0);
		var n2:Number = interp.numarg(b, 1);
		var low:Number = (n1 <= n2) ? n1 : n2;
		var hi:Number = (n1 <= n2) ? n2 : n1;
		if (low == hi) return low;

		// if both low and hi are ints, truncate the result to an int
		var ba1:BlockArg = b.args[0] as BlockArg;
		var ba2:BlockArg = b.args[1] as BlockArg;
		var int1:Boolean = ba1 ? ba1.numberType == BlockArg.NT_INT : int(n1) == n1;
		var int2:Boolean = ba2 ? ba2.numberType == BlockArg.NT_INT : int(n2) == n2;
		if (int1 && int2)
			return low + int(Math.random() * ((hi + 1) - low));

		return (Math.random() * (hi - low)) + low;
	}

	private function primLetterOf(b:Block):String {
		var s:String = interp.arg(b, 1);
		var i:int = interp.numarg(b, 0) - 1;
		if ((i < 0) || (i >= s.length)) return "";
		return s.charAt(i);
	}

	private function primModulo(b:Block):Number {
		var n:Number = interp.numarg(b, 0);
		var modulus:Number = interp.numarg(b, 1);
		var result:Number = n % modulus;
		if (result / modulus < 0) result += modulus;
		return result;
	}

	private function primMathFunction(b:Block):Number {
		var op:* = interp.arg(b, 0);
		var n:Number = interp.numarg(b, 1);
		switch(op) {
		case "abs": return Math.abs(n);
		case "floor": return Math.floor(n);
		case "ceiling": return Math.ceil(n);
		case "int": return n - (n % 1); // used during alpha, but removed from menu
		case "sqrt": return Math.sqrt(n);
		case "sin": return Math.sin((Math.PI * n) / 180);
		case "cos": return Math.cos((Math.PI * n) / 180);
		case "tan": return Math.tan((Math.PI * n) / 180);
		case "asin": return (Math.asin(n) * 180) / Math.PI;
		case "acos": return (Math.acos(n) * 180) / Math.PI;
		case "atan": return (Math.atan(n) * 180) / Math.PI;
		case "ln": return Math.log(n);
		case "log": return Math.log(n) / Math.LN10;
		case "e ^": return Math.exp(n);
		case "10 ^": return Math.pow(10, n);
		}
		return 0;
	}

	private static const emptyDict:Dictionary = new Dictionary();
	private static var lcDict:Dictionary = new Dictionary();
	public static function compare(a1:*, a2:*):int {
		// This is static so it can be used by the list "contains" primitive.
		var n1:Number = Interpreter.asNumber(a1);
		var n2:Number = Interpreter.asNumber(a2);
		// X != X is faster than isNaN()
		if (n1 != n1 || n2 != n2) {
			// Suffix the strings to avoid properties and methods of the Dictionary class (constructor, hasOwnProperty, etc)
			if (a1 is String && emptyDict[a1]) a1 += '_';
			if (a2 is String && emptyDict[a2]) a2 += '_';

			// at least one argument can't be converted to a number: compare as strings
			var s1:String = lcDict[a1];
			if(!s1) s1 = lcDict[a1] = String(a1).toLowerCase();
			var s2:String = lcDict[a2];
			if(!s2) s2 = lcDict[a2] = String(a2).toLowerCase();
			return s1.localeCompare(s2);
		} else {
			// compare as numbers
			if (n1 < n2) return -1;
			if (n1 == n2) return 0;
			if (n1 > n2) return 1;
		}
		return 1;
	}

	private function primCreateCloneOf(b:Block):void {
		var objName:String = interp.arg(b, 0);
		var proto:ScratchSprite = app.stagePane.spriteNamed(objName);
		if ('_myself_' == objName) proto = interp.activeThread.target;
		if (!proto) return;
		if (app.runtime.cloneCount > MaxCloneCount) return;
		var clone:ScratchSprite = new ScratchSprite();
		if (proto.parent == app.stagePane)
			app.stagePane.addChildAt(clone, app.stagePane.getChildIndex(proto));
		else
			app.stagePane.addChild(clone);

		clone.initFrom(proto, true);
		clone.objName = proto.objName;
		clone.isClone = true;
		for each (var stack:Block in clone.scripts) {
			if (stack.op == "whenCloned") {
				interp.startThreadForClone(stack, clone);
			}
		}
		app.runtime.cloneCount++;
	}

	private function primDeleteClone(b:Block):void {
		var clone:ScratchSprite = interp.targetSprite();
		if ((clone == null) || (!clone.isClone) || (clone.parent == null)) return;
		if (clone.bubble && clone.bubble.parent) {
			clone.bubble.parent.removeChild(clone.bubble);
			clone.bubble = null; // prevent potential exception inside hideAskBubble (via clearAskPrompts in stopThreadsFor below)
		}
		clone.parent.removeChild(clone);
		app.interp.stopThreadsFor(clone);
		app.runtime.cloneCount--;
	}

	private function primBoolean(b:Block):Boolean 
	{
		/*if (interp.arg(b,0) == 0){
			return false;
		}else if(interp.arg(b,0) == false){
			return false;
		}else if(interp.arg(b,0) == ""){
			return false;
		}else if(interp.arg(b,0) == null){
			return false;
		}else if(interp.arg(b,0) == -0){
			return false;
		}else{
			return true
		}*/
		return !!interp.arg(b, 0);
	}

	private function primShowText(b:Block):void
	{
		
	}

	private function primIfElse(b:Block):String{
		if (interp.boolarg(b,0) == true){
			return interp.arg(b,1);
		}else{
			return interp.arg(b,2);
		}
	}

	private function primIfElseBool(b:Block):*
	{
		if (interp.boolarg(b,0) == true){
			return interp.boolarg(b,1);
		}else{
			return interp.boolarg(b,2);
		}
	}

	private function primTurbo(b:Block):void
	{
		interp.turboMode = !interp.turboMode;
		Scratch.app.stagePart.refresh();
	}

	/*
	temp vars are NOT actually true temp vars. This is a primitive(no pun intended) way of dictionaries(or objects, as some call)
	for now, this way of looping through the object doesn't work. 
	if this gets implemented again, this need to be fixed
	*/

	private function primGetTempVar(b:Block):*
	{
		
		var targetIndex:int = -1; // -1 means "not found"

		
		for (var i:int = 0; i < tempVars.length; i++) 
		{
			// Check if the name matches at this specific index
			if (tempVars[i].name == interp.arg(b, 0)) 
			{
				targetIndex = i; // Save the index number!
				break;           // Stop looping immediately since we found it
			}
		}

		
		if (targetIndex != -1) 
		{
			//trace("Found match at index position: " + targetIndex);
			return tempVars[targetIndex].value; 
		}
		
		
		return null;

	}

	private function primSetTempVar(b:Block):void
	{
		var targetIndex:int = -1; // -1 means "not found"

		//Loop using numerical index positions
		for (var i:int = 0; i < tempVars.length; i++) 
		{
			// Check if the name matches at this specific index
			if (tempVars[i].name == interp.arg(b, 0)) 
			{
				targetIndex = i; // Save the index number!
				break;           // Stop looping immediately since we found it
			}
		}

		
		if (targetIndex != -1) 
		{
			//trace("Found match at index position: " + targetIndex);
			tempVars[targetIndex] = interp.arg(b, 1)
		}
		
		
		//return null;
	}

	private function primChangeTempVar(b:Block):void
	{
		/*for each (var item:String in tempVars.value) {
			if (item == interp.arg(b, 0)) {
				break;//return(item.value);
			}
		}*/
	}

	


	private function primRandomJoke(b:Block):*
	{
		var jokesArray:Array = [
								"Why don't scientists trust atoms? Because they make up everything!",
								"Why did the scarecrow win an award? Because he was outstanding in his field.",
																"What do you call a fake noodle? An impasta.",
								"Why do we tell actors to 'break a leg'? Because every play has a cast.",
								"Why did Beethoven get rid of his chickens? All they ever said was, 'Bach, Bach, Bach!'",
									"Why cannot you put two half-dollars in your pocket? Because two halves make a hole, and your money will fall out!",
								"What does a condiment wizard perform? Saucery",
																"Which is faster, hot or cold? Hot, because you can catch cold.",
								"Why do bees have sticky hair? Because they use a honeycomb.",
																"Why couldn't the bicycle stand up by itself? It was two tired.",
								"Why do fish have bad grades? Because they never go above sea.",
																"What do you get when you cross a catepillar and a parrot? A walkie talkie.",
																"The Sun is Hot[citation needed]",
																"The leading cause of dry skin is towels.",
																"Stop hating on Lazy people, we didn't even do anything",
								];

															// 2. Generate a random index based on the array's length
															// Math.random() * jokesArray.length gives a decimal from 0 to 3.999...
															// Math.floor() rounds it down to a whole integer (0, 1, 2, or 3)
		var randomIndex:int = Math.floor(Math.random() * jokesArray.length);

															// 3. Fetch and display the joke
		var randomJokeResult:String = jokesArray[randomIndex];

		return(randomJokeResult);
	}

	/*private function primAlterString(b:Block):String {
		var string:* = interp.arg(b, 1);
		var type:* = interp.arg(b,0);
		switch(type) {
		case "uppercase": return string.toUpperCase();
		case "lowercase": return string.toLowerCase();
		case "reverse": return reverseString(string);
		case "shuffle": return initRandomizeArray(string);
		case "trim blanks of": return trimBlanks(string);
		}
		return ""; //Just return a blank string upon error
	}
	
	private function reverseString(tString:String):String {
		var tmp_array:Array=tString.split("");
		tmp_array.reverse();
		var tmpString:String=tmp_array.join("");
		return tmpString;
	}
	
	private function initRandomizeArray(string:String):String {
		var tmp_array:Array = string.split("");
		return randomizeArray(tmp_array);
	}
	
	private function randomizeArray(array:Array):String {
		var newArray:Array = new Array();
		while(array.length > 0){
			newArray.push(array.splice(Math.floor(Math.random()*array.length), 1));
		}
		var tmpString:String = newArray.join("");
		return tmpString;
	}
	
	private function trimBlanks(str:String):String {
		var rex:RegExp = /[\s\r\n]+/gim;
		str = str.replace(rex,'');
		return str;
	}*/

	private function primLettersBetween(b:Block):String {
		var s:String = interp.arg(b, 2);
		var n1:int = interp.numarg(b, 0) - 1;
		var n2:int = interp.numarg(b, 1);
		if ((n1 < 0) || (n2 >= s.length)) return "";
		return s.slice(n1, n2);
	}

}
}