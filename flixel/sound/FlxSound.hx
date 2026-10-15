package flixel.sound;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.system.FlxAssets.FlxSoundAsset;
import flixel.tweens.FlxTween;
import flixel.util.FlxStringUtil;
import lime.media.AudioSource;
import openfl.media.Sound;
import openfl.utils.ByteArray;

/**
 * This is the universal flixel sound object, used for streaming, music, and sound effects.
 */
class FlxSound extends FlxBasic
{
	/**
	 * The x position of this sound in world coordinates.
	 * Only really matters if you are doing proximity/panning stuff.
	 */
	public var x:Float;
	
	/**
	 * The y position of this sound in world coordinates.
	 * Only really matters if you are doing proximity/panning stuff.
	 */
	public var y:Float;
	
	/**
	 * Whether or not this sound should be automatically destroyed when you switch states.
	 */
	public var persist:Bool;
	
	/**
	 * Whether to call `destroy()` when the sound has finished playing.
	 */
	public var autoDestroy:Bool;
	
	/**
	 * Tracker for sound complete callback. If assigned, will be called
	 * each time when sound reaches its end.
	 */
	public var onComplete:Void->Void;
	
	/**
	 * Pan amount. -1 = full left, 1 = full right. Proximity based panning overrides this.
	 * 
	 * Note: On desktop targets this only works with mono sounds, due to limitations of OpenAL.
	 * More info: [OpenFL Forums - SoundTransform.pan does not work](https://community.openfl.org/t/windows-legacy-soundtransform-pan-does-not-work/6616/2?u=geokureli)
	 */
	public var pan(get, set):Float;
	
	/**
	 * Whether or not the sound is currently playing.
	 */
	public var playing(get, never):Bool;
	
	/**
	 * Set volume to a value between 0 and 1 to change how this sound is.
	 */
	public var volume(get, set):Float;
	
	/**
	 * Set pitch, which also alters the playback speed. Default is 1.
	 */
	public var pitch(get, set):Float;
	
	/**
	 * The position in runtime of the music playback in milliseconds.
	 */
	public var time(get, set):Float;
	
	/**
	 * The length of the sound in milliseconds.
	 * @since 4.2.0
	 */
	public var length(get, never):Float;
	
	/**
	 * The sound group this sound belongs to, can only be in one group.
	 * NOTE: This setter is deprecated, use `group.add(sound)` or `group.remove(sound)`.
	 */
	public var group(default, set):FlxSoundGroup;
	
	/**
	 * Whether or not this sound should loop.
	 */
	public var looped:Bool;
	
	/**
	 * In case of looping, the point (in milliseconds) from where to restart the sound when it loops back
	 * @since 4.1.0
	 */
	public var loopTime:Float = 0;
	
	/**
	 * The tween used to fade this sound's volume in and out (set via `fadeIn()` and `fadeOut()`)
	 * @since 4.1.0
	 */
	public var fadeTween:FlxTween;
	
	/**
	 * Internal tracker for the loaded sound asset.
	 */
	@:allow(flixel.system.frontEnds.SoundFrontEnd.load)
	var _sound:Sound;
	
	/**
	 * Internal tracker for a lime audio source object.
	 */
	var _source:AudioSource;
	
	/**
	 * Internal tracker for whether the sound is paused or not (not the same as stopped).
	 */
	var _paused:Bool;
	
	/**
	 * Internal tracker for volume.
	 */
	var _volume:Float;
	
	/**
	 * Internal tracker for pitch.
	 */
	var _pitch:Float = 1.0;
	
	/**
	 * Internal tracker for total volume adjustment.
	 */
	var _volumeAdjust:Float = 1.0;
	
	/**
	 * Internal tracker for pan, since `AudioSource` has no native pan property - see the `pan` doc above.
	 */
	var _pan:Float = 0;
	
	/**
	 * Internal tracker for the sound's "target" (for proximity and panning).
	 */
	var _target:FlxObject;
	
	/**
	 * Internal tracker for the maximum effective radius of this sound (for proximity and panning).
	 */
	var _radius:Float;
	
	/**
	 * Internal tracker for whether to pan the sound left and right.  Default is false.
	 */
	var _proximityPan:Bool;
	
	/**
	 * Helper var to prevent the sound from playing after focus was regained when it was already paused.
	 */
	var _resumeOnFocus:Bool = false;
	
	/**
	 * The FlxSound constructor gets all the variables initialized, but NOT ready to play a sound yet.
	 */
	public function new()
	{
		super();
		reset();
	}
	
	/**
	 * An internal function for clearing all the variables used by sounds.
	 */
	function reset():Void
	{
		destroy();
		
		x = 0;
		y = 0;
		
		_paused = false;
		_volume = 1.0;
		_volumeAdjust = 1.0;
		_pan = 0;
		looped = false;
		loopTime = 0.0;
		_target = null;
		_radius = 0;
		_proximityPan = false;
		visible = false;
		autoDestroy = false;
	}
	
	override public function destroy():Void
	{
		// Prevents double destroy
		if (group != null)
			group.remove(this);
			
		exists = false;
		active = false;
		_target = null;
		
		if (fadeTween != null)
		{
			fadeTween.cancel();
			fadeTween = null;
		}
		
		if (_source != null)
		{
			_source.onComplete.remove(stopped);
			_source.dispose();
			_source = null;
		}
		
		_sound = null;
		
		onComplete = null;
		
		super.destroy();
	}
	
	/**
	 * Handles fade out, fade in, panning and proximity, operations each frame.
	 */
	override public function update(elapsed:Float):Void
	{
		if (!playing)
			return;
			
		_volumeAdjust = 1.0;
		
		// Distance-based volume control
		if (_target != null)
		{
			final targetPos = _target.getPosition();
			_volumeAdjust = 1 - FlxMath.bound(targetPos.distanceTo(FlxPoint.weak(x, y)) / _radius, 0, 1);
			targetPos.put();
			
			if (_proximityPan)
				pan = FlxMath.bound((x - _target.x) / _radius, -1, 1);
		}
		
		updateVolume();
	}
	
	override public function kill():Void
	{
		super.kill();
		cleanup(false);
	}
	
	/**
	 * One of the main setup functions for sounds, this function loads a sound from an embedded MP3.
	 *
	 * **Note:** If the `FLX_DEFAULT_SOUND_EXT` flag is enabled, you may omit the file extension
	 *
	 * @param	EmbeddedSound	An embedded Class object representing an MP3 file.
	 * @param	Looped			Whether or not this sound should loop endlessly.
	 * @param	AutoDestroy		Whether or not this FlxSound instance should be destroyed when the sound finishes playing.
	 * 							Default value is false, but `FlxG.sound.play()` and `FlxG.sound.stream()` will set it to true by default.
	 * @param	OnComplete		Called when the sound finished playing
	 * @return	This FlxSound instance (nice for chaining stuff together, if you're into that).
	 */
	public function loadEmbedded(EmbeddedSound:FlxSoundAsset, Looped:Bool = false, AutoDestroy:Bool = false, ?OnComplete:Void->Void):FlxSound
	{
		if (EmbeddedSound == null)
			return this;
			
		cleanup(true);
		
		if ((EmbeddedSound is Sound))
		{
			_sound = EmbeddedSound;
		}
		else if ((EmbeddedSound is Class))
		{
			_sound = Type.createInstance(EmbeddedSound, []);
		}
		else if ((EmbeddedSound is String))
		{
			if (FlxG.assets.exists(EmbeddedSound, SOUND))
				_sound = FlxG.assets.getSoundUnsafe(EmbeddedSound);
			else
				FlxG.log.error('Could not find a Sound asset with an ID of \'$EmbeddedSound\'.');
		}
		
		return init(Looped, AutoDestroy, OnComplete);
	}
	
	function init(Looped:Bool = false, AutoDestroy:Bool = false, ?OnComplete:Void->Void):FlxSound
	{
		looped = Looped;
		autoDestroy = AutoDestroy;
		exists = true;
		onComplete = OnComplete;
		
		if (_sound != null)
		{
			@:privateAccess
			_source = new AudioSource(_sound.__buffer);
			_source.onComplete.add(stopped);
		}
		
		pitch = 1;
		updateVolume();
		updatePan();
		return this;
	}
	
	/**
	 * Call this function if you want this sound's volume to change
	 * based on distance from a particular FlxObject.
	 *
	 * @param	X			The X position of the sound.
	 * @param	Y			The Y position of the sound.
	 * @param	TargetObject		The object you want to track.
	 * @param	Radius			The maximum distance this sound can travel.
	 * @param	Pan			Whether panning should be used in addition to the volume changes.
	 * @return	This FlxSound instance (nice for chaining stuff together, if you're into that).
	 */
	public function proximity(X:Float, Y:Float, TargetObject:FlxObject, Radius:Float, Pan:Bool = true):FlxSound
	{
		x = X;
		y = Y;
		_target = TargetObject;
		_radius = Radius;
		_proximityPan = Pan;
		return this;
	}
	
	/**
	 * Call this function to play the sound - also works on paused sounds.
	 *
	 * @param   ForceRestart   Whether to start the sound over or not.
	 *                         Default value is false, meaning if the sound is already playing or was
	 *                         paused when you call play(), it will continue playing from its current
	 *                         position, NOT start again from the beginning.
	 * @param   StartTime      At which point to start playing the sound, in milliseconds.
	 *                         Only used when the sound starts from the beginning (or `ForceRestart` is true).
	 */
	public function play(ForceRestart:Bool = false, StartTime:Float = 0.0):FlxSound
	{
		if (!exists || _source == null)
			return this;
			
		if (ForceRestart)
		{
			startSound(StartTime);
		}
		else if (!playing)
		{
			if (_paused)
				resume();
			else
				startSound(StartTime);
		}
		
		return this;
	}
	
	/**
	 * Unpause a sound. Only works on sounds that have been paused.
	 */
	public function resume():FlxSound
	{
		if (!_paused || _source == null)
			return this;
			
		_paused = false;
		_source.play();
		active = true;
		
		return this;
	}
	
	/**
	 * Call this function to pause this sound.
	 */
	public function pause():FlxSound
	{
		if (!playing)
			return this;
			
		_paused = true;
		_source.pause();
		active = false;
		
		return this;
	}
	
	/**
	 * Call this function to stop this sound.
	 */
	public inline function stop():FlxSound
	{
		cleanup(autoDestroy, true);
		return this;
	}
	
	/**
	 * Helper function that tweens this sound's volume.
	 *
	 * @param	Duration	The amount of time the fade-out operation should take.
	 * @param	To			The volume to tween to, 0 by default.
	 */
	public inline function fadeOut(Duration:Float = 1, ?To:Float = 0, ?onComplete:FlxTween->Void):FlxSound
	{
		fadeTween?.cancel();
		fadeTween = FlxTween.num(volume, To, Duration, {onComplete: onComplete}, (f:Float) -> volume = f);
		return this;
	}
	
	/**
	 * Helper function that tweens this sound's volume.
	 *
	 * @param	Duration	The amount of time the fade-in operation should take.
	 * @param	From		The volume to tween from, 0 by default.
	 * @param	To			The volume to tween to, 1 by default.
	 */
	public inline function fadeIn(Duration:Float = 1, From:Float = 0, To:Float = 1, ?onComplete:FlxTween->Void):FlxSound
	{
		if (!playing)
			play();
			
		fadeTween?.cancel();
		fadeTween = FlxTween.num(From, To, Duration, {onComplete: onComplete}, (f:Float) -> volume = f);
		return this;
	}
	
	/**
	 * Returns the currently selected "real" volume of the sound (takes fades and proximity into account).
	 *
	 * @return	The adjusted volume of the sound.
	 */
	public inline function getActualVolume():Float
	{
		return _volume * _volumeAdjust;
	}
	
	/**
	 * Helper function to set the coordinates of this object.
	 * Sound positioning is used in conjunction with proximity/panning.
	 *
	 * @param        X        The new x position
	 * @param        Y        The new y position
	 */
	public inline function setPosition(X:Float = 0, Y:Float = 0):Void
	{
		x = X;
		y = Y;
	}
	
	/**
	 * Call after adjusting the volume to update the sound's settings.
	 */
	@:allow(flixel.sound.FlxSoundGroup)
	function updateVolume():Void
	{
		if (_source != null)
			_source.gain = calcTransformVolume();
	}
	
	/**
	 * Call after adjusting the pan to update the sound's settings.
	 */
	@:allow(flixel.sound.FlxSoundGroup)
	function updatePan():Void
	{
		if (_source != null)
			_source.pan = _pan;
	}
	
	function calcTransformVolume():Float
	{
		final volume = (group != null ? group.getVolume() : 1.0) * _volume * _volumeAdjust;
		
		#if FLX_SOUND_SYSTEM
		if (FlxG.sound.muted)
			return 0.0;
			
		return FlxG.sound.volume * volume;
		#else
		return volume;
		#end
	}
	
	/**
	 * An internal helper function used to (re)start playback on the persistent `_source`
	 * from a given position. Doesn't create or destroy anything - just seeks and plays.
	 */
	function startSound(StartTime:Float):Void
	{
		if (_source == null)
			return;
			
		_paused = false;
		
		_source.currentTime = StartTime;
		
		_source.play();
		
		active = true;
	}
	
	/**
	 * An internal helper called when the source finishes playing.
	 * Restarts looped sounds, otherwise cleans up (and destroys the sound if `autoDestroy` is enabled).
	 */
	function stopped():Void
	{
		if (onComplete != null)
			onComplete();
			
		if (looped)
			startSound(loopTime);
		else
			cleanup(autoDestroy);
	}
	
	/**
	 * An internal helper function used to clean up (and potentially re-use) finished sounds.
	 * Will stop the current sound, plus any other commands ordered by the passed in parameters.
	 *
	 * @param  destroySound    Whether or not to destroy the sound. If this is true,
	 *                         everything is reset and `resetPosition` is ignored.
	 * @param  resetPosition   Whether or not to clear the paused state, so the next `play()`
	 *                         starts from the beginning instead of resuming.
	 */
	function cleanup(destroySound:Bool, resetPosition:Bool = true):Void
	{
		if (destroySound)
		{
			reset();
			return;
		}
		
		if (_source != null)
			_source.stop();
			
		active = false;
		
		if (resetPosition)
			_paused = false;
	}
	
	#if FLX_SOUND_SYSTEM
	@:allow(flixel.system.frontEnds.SoundFrontEnd)
	function onFocus():Void
	{
		if (_resumeOnFocus)
		{
			_resumeOnFocus = false;
			resume();
		}
	}
	
	@:allow(flixel.system.frontEnds.SoundFrontEnd)
	function onFocusLost():Void
	{
		_resumeOnFocus = playing;
		pause();
	}
	#end
	
	@:deprecated("sound.group = myGroup is deprecated, use myGroup.add(sound)") // 5.7.0
	function set_group(value:FlxSoundGroup):FlxSoundGroup
	{
		if (value != null)
		{
			// add to new group, also removes from prev and calls updateTransform
			value.add(this);
		}
		else
		{
			// remove from prev group, also calls updateTransform
			group.remove(this);
		}
		return value;
	}
	
	inline function get_playing():Bool
	{
		return _source != null && _source.playing;
	}
	
	inline function get_volume():Float
	{
		return _volume;
	}
	
	function set_volume(Volume:Float):Float
	{
		_volume = FlxMath.bound(Volume, 0, 1);
		updateVolume();
		return _volume;
	}
	
	inline function get_pitch():Float
	{
		return _pitch;
	}
	
	function set_pitch(v:Float):Float
	{
		if (_source != null)
			_source.pitch = v;
			
		return _pitch = v;
	}
	
	inline function get_pan():Float
	{
		return _pan;
	}
	
	function set_pan(pan:Float):Float
	{
		_pan = FlxMath.bound(pan, -1, 1);
		updatePan();
		return _pan;
	}
	
	inline function get_time():Float
	{
		return _source != null ? _source.currentTime : 0;
	}
	
	function set_time(time:Float):Float
	{
		if (_source != null)
			_source.currentTime = time;
			
		return time;
	}
	
	inline function get_length():Float
	{
		return _source != null ? _source.length : 0;
	}
	
	override public function toString():String
	{
		return FlxStringUtil.getDebugString([
			LabelValuePair.weak("playing", playing),
			LabelValuePair.weak("time", time),
			LabelValuePair.weak("length", length),
			LabelValuePair.weak("volume", volume)
		]);
	}
}
