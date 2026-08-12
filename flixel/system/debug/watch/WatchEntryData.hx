package flixel.system.debug.watch;

#if polymod
import polymod.hscript._internal.Expr;
#elseif hscript
import hscript.Expr;
#end

enum WatchEntryData
{
	/**
	 * `object.field` resolved via `Reflect.getProperty()`.
	 */
	FIELD(object:Dynamic, field:String);

	/**
	 * Manually updated values.
	 */
	QUICK(value:String);

	/**
	 * Haxe expression evaluated with hscript.
	 */
	EXPRESSION(expression:String, parsedExpr:#if (polymod || hscript) Expr #else String #end);
	
	/**
	 * A function that returns the value to display.
	 */
	FUNCTION(func:()->Dynamic);
}
