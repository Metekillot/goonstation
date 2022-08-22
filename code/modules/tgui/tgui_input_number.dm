/*
 * Copyright 2021 jlsnow301 (https://github.com/jlsnow301)
 * Licensed under MIT (https://choosealicense.com/licenses/mit/)
 */

/**
 * Creates a TGUI window with a number input. Returns the user's response as num | null.
 *
 * This proc should be used to create windows for number entry that the caller will wait for a response from.
 * If tgui fancy chat is turned off: Will return a normal input. If a max or min value is specified, will
 * validate the input inside the UI and ui_act.
 *
 * Arguments:
 * * user - The user to show the numbox to.
 * * message - The content of the numbox, shown in the body of the TGUI window.
 * * title - The title of the numbox modal, shown on the top of the TGUI window.
 * * default - The default (or current) value, shown as a placeholder. Users can press refresh with this.
 * * max_value - Specifies a maximum value. If none is set, any number can be entered. Pressing "max" defaults to 1000.
 * * min_value - Specifies a minimum value. Often 0.
 * * timeout - The timeout of the numbox, after which the modal will close and qdel itself. Set to zero for no timeout.
 */
/proc/tgui_input_number(mob/user, message, title = "Number Input", default, max_value, min_value, timeout = 0)
	if (!user)
		user = usr
	if (!istype(user))
		if (istype(user, /client))
			var/client/client = user
			user = client.mob
		else
			return
	if(!user)
		return
	var/datum/tgui_input_number/numbox = new(user, message, title, default, max_value, min_value, timeout)
	numbox.ui_interact(user)
	numbox.wait()
	if (numbox)
		. = numbox.entry
		qdel(numbox)

/**
 * Creates an asynchronous TGUI number input window with an associated callback.
 *
 * This proc should be used to create numboxes that invoke a callback with the user's entry.
 *
 * Arguments:
 * * user - The user to show the numbox to.
 * * message - The content of the numbox, shown in the body of the TGUI window.
 * * title - The title of the numbox modal, shown on the top of the TGUI window.
 * * default - The default (or current) value, shown as a placeholder. Users can press refresh with this.
 * * max_value - Specifies a maximum value. If none is set, any number can be entered. Pressing "max" defaults to 1000.
 * * min_value - Specifies a minimum value. Often 0.
 * * callback - The callback to be invoked when a choice is made.
 * * timeout - The timeout of the numbox, after which the modal will close and qdel itself. Disabled by default, can be set to seconds otherwise.
 */
/proc/tgui_input_number_async(mob/user, message, title = "Number Input", default, max_value, min_value, datum/callback/callback, timeout = 60 SECONDS)
	if (!user)
		user = usr
	if (!istype(user))
		if (istype(user, /client))
			var/client/client = user
			user = client.mob
		else
			return
	var/datum/tgui_input_number/async/numbox = new(user, message, title, default, max_value, min_value, callback, timeout)
	numbox.ui_interact(user)

/**
 * # tgui_input_number
 *
 * Datum used for instantiating and using a TGUI-controlled numbox that prompts the user with
 * a message and has an input for text entry.
 */
/datum/tgui_input_number
	/// Boolean field describing if the tgui_input_number was closed by the user.
	var/closed
	/// The default (or current) value, shown as a default. Users can press reset with this.
	var/default
	/// The entry that the user has return_typed in.
	var/entry
	/// The maximum value that can be entered.
	var/max_value
	/// The prompt's body, if any, of the TGUI window.
	var/message
	/// The minimum value that can be entered.
	var/min_value
	/// The time at which the tgui_modal was created, for displaying timeout progress.
	var/start_time
	/// The lifespan of the tgui_input_number, after which the window will close and delete itself.
	var/timeout
	/// The title of the TGUI window
	var/title


/datum/tgui_input_number/New(mob/user, message, title, default, max_value, min_value, timeout)
	src.default = default
	src.max_value = max_value
	src.message = message
	src.min_value = min_value
	src.title = title
	if (timeout)
		src.timeout = timeout
		start_time = TIME
		SPAWN(timeout)
			qdel(src)
	. = ..()

/**
 * Waits for a user's response to the tgui_input_number's prompt before returning. Returns early if
 * the window was closed by the user.
 */
/datum/tgui_input_number/proc/wait()
	while (!entry && !closed && !QDELETED(src))
		sleep(1)

/datum/tgui_input_number/disposing(force, ...)
	tgui_process.close_uis(src)
	. = ..()

/datum/tgui_input_number/ui_interact(mob/user, datum/tgui/ui)
	ui = tgui_process.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "NumberInputModal")
		ui.open()

/datum/tgui_input_number/ui_close(mob/user)
	. = ..()
	closed = TRUE

/datum/tgui_input_number/ui_state(mob/user)
	return tgui_always_state

/datum/tgui_input_number/ui_data(mob/user)
	. = list(
		"init_value" = default || 0, // Default is a reserved keyword
		"max_value" = max_value,
		"message" = message,
		"min_value" = min_value || 0,
		"title" = title,
	)
	if(timeout)
		.["timeout"] = clamp(((timeout - (TIME - start_time) - 1 SECONDS) / (timeout - 1 SECONDS)), 0, 1)

/datum/tgui_input_number/ui_act(action, list/params)
	. = ..()
	if (.)
		return
	switch(action)
		if("submit")
			if(max_value && (length(params["entry"]) > max_value))
				return FALSE
			if(min_value && (length(params["entry"]) < min_value))
				return FALSE
			set_entry(params["entry"])
			tgui_process.close_uis(src)
			return TRUE
		if("cancel")
			set_entry(null)
			tgui_process.close_uis(src)
			return TRUE

/datum/tgui_input_number/proc/set_entry(entry)
		src.entry = entry

/**
 * # async tgui_input_number
 *
 * An asynchronous version of tgui_input_number to be used with callbacks instead of waiting on user responses.
 */
/datum/tgui_input_number/async
	/// The callback to be invoked by the tgui_input_number upon having a choice made.
	var/datum/callback/callback

/datum/tgui_input_number/async/New(mob/user, message, title, default, max_value, min_value, callback, timeout)
	..(user, message, title, default, max_value, min_value, timeout)
	src.callback = callback

/datum/tgui_input_number/async/disposing(force, ...)
	qdel(callback)
	callback = null
	. = ..()

/datum/tgui_input_number/async/set_entry(entry)
	. = ..()
	if(!isnull(src.entry))
		callback?.InvokeAsync(src.entry)

/datum/tgui_input_number/async/wait()
	return
