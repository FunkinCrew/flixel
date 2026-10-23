package flixel.input;

class FlxInput<T> implements IFlxInput
{
	public var ID:T;

	public var justReleased(get, never):Bool;
	public var released(get, never):Bool;
	public var pressed(get, never):Bool;
	public var justPressed(get, never):Bool;

	public var current:FlxInputState = RELEASED;
	public var last:FlxInputState = RELEASED;

	/**
	 * If `true`, a `release()` call that arrives before `JUST_PRESSED` is set
	 * causes `JUST_RELEASED` to be delayed by a frame.
	 * This prevents inputs shorter than one frame from getting dropped.
	 */
	public var deferRelease:Bool = true;

	/**
	 * Whether the key was pressed l
	 */
	var pendingRelease:Bool = false;

	public function new(ID:T)
	{
		this.ID = ID;
	}

	public function press():Void
	{
		pendingRelease = false;
		last = current;
		current = pressed ? PRESSED : JUST_PRESSED;
	}

	public function release():Void
	{
		if (deferRelease)
		{
			if (current == JUST_PRESSED && last != JUST_PRESSED)
			{
				pendingRelease = true;
				return;
			}
		}

		last = current;
		current = pressed ? JUST_RELEASED : RELEASED;
	}

	public function update():Void
	{
		if (pendingRelease && last == JUST_PRESSED)
		{
			// JUST_PRESSED has been available for at least one frame.
			// We can now send JUST_RELEASED without the input getting dropped.
			pendingRelease = false;
			release();
		}
		else if (last == JUST_RELEASED && current == JUST_RELEASED)
		{
			current = RELEASED;
		}
		else if (last == JUST_PRESSED && current == JUST_PRESSED)
		{
			current = PRESSED;
		}

		last = current;
	}

	public function reset():Void
	{
		current = RELEASED;
		last = RELEASED;
		pendingRelease = false;
	}

	public function hasState(state:FlxInputState):Bool
	{
		return switch (state)
		{
			case JUST_RELEASED: justReleased;
			case RELEASED: released;
			case PRESSED: pressed;
			case JUST_PRESSED: justPressed;
		}
	}

	inline function get_justReleased():Bool
	{
		return current == JUST_RELEASED;
	}

	inline function get_released():Bool
	{
		return current == RELEASED || justReleased;
	}

	inline function get_pressed():Bool
	{
		return current == PRESSED || justPressed;
	}

	inline function get_justPressed():Bool
	{
		return current == JUST_PRESSED;
	}
}

enum abstract FlxInputState(Int) from Int
{
	var JUST_RELEASED = -1;
	var RELEASED = 0;
	var PRESSED = 1;
	var JUST_PRESSED = 2;
}
