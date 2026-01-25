--!strict

local KapraoSignal = {}

-- // TYPE DEFINITIONS //

-- [TYPE 1] Standard: arguments are inferred directly from T...
export type Connection<T...> = {
	Connected: boolean,
	Signal: Signal<T...>,
	Disconnect: (self: Connection<T...>) -> (),
}

export type Signal<T...> = {
	Dead: boolean,
	EverFired: boolean,
	LatestFiredValue: {any},
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection<T...>?,
	ConnectWithLast: (self: Signal<T...>, callback: (T...) -> ()) -> Connection<T...>?,
	ImmediateConnect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection<T...>?,
	ImmediateConnectWithLast: (self: Signal<T...>, callback: (T...) -> ()) -> Connection<T...>?,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> (T...),
	WaitIfNeverFired: (self: Signal<T...>) -> (T...),
	MassDisconnect: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

-- [TYPE 2] Explicit: U is the callback type, V... are the fire parameters
export type ExplicitConnection<U, V...> = {
	Connected: boolean,
	Signal: ExplicitSignal<U, V...>,
	Disconnect: (self: ExplicitConnection<U, V...>) -> (),
}

export type ExplicitSignal<U, V...> = {
	Dead: boolean,
	EverFired: boolean,
	LatestFiredValue: {any},
	Connect: (self: ExplicitSignal<U, V...>, callback: U) -> ExplicitConnection<U, V...>?,
	ConnectWithLast: (self: ExplicitSignal<U, V...>, callback: U) -> ExplicitConnection<U, V...>?,
	ImmediateConnect: (self: ExplicitSignal<U, V...>, callback: U) -> ExplicitConnection<U, V...>?,
	ImmediateConnectWithLast: (self: ExplicitSignal<U, V...>, callback: U) -> ExplicitConnection<U, V...>?,
	Fire: (self: ExplicitSignal<U, V...>, V...) -> (),
	Wait: (self: ExplicitSignal<U, V...>) -> (V...),
	WaitIfNeverFired: (self: ExplicitSignal<U, V...>) -> (V...),
	MassDisconnect: (self: ExplicitSignal<U, V...>) -> (),
	Destroy: (self: ExplicitSignal<U, V...>) -> (),
}

-- [TYPE 3] Any: Accepts any parameters (loose typing)
export type AnyConnection = {
	Connected: boolean,
	Signal: AnySignal,
	Disconnect: (self: AnyConnection) -> (),
}

export type AnySignal = {
	Dead: boolean,
	EverFired: boolean,
	LatestFiredValue: {any},
	Connect: (self: AnySignal, callback: (...any) -> ()) -> AnyConnection?,
	ConnectWithLast: (self: AnySignal, callback: (...any) -> ()) -> AnyConnection?,
	ImmediateConnect: (self: AnySignal, callback: (...any) -> ()) -> AnyConnection?,
	ImmediateConnectWithLast: (self: AnySignal, callback: (...any) -> ()) -> AnyConnection?,
	Fire: (self: AnySignal, ...any) -> (),
	Wait: (self: AnySignal) -> (...any),
	WaitIfNeverFired: (self: AnySignal) -> (...any),
	MassDisconnect: (self: AnySignal) -> (),
	Destroy: (self: AnySignal) -> (),
}

-- // INTERNAL IMPLEMENTATION //

local ConnectionMethods = {}
function ConnectionMethods:Disconnect()
	if self.Connected then
		if self.List and type(self.List) == 'table' then
			self.List[self] = nil
		end
		self.Signal = nil
		(self :: any).List = nil
		self.Connected = false
	end
end

local SignalMethods = {}

function SignalMethods:Connect(callback: (...any) -> ()): any
	if self.Connects then
		local connection = setmetatable({
			Signal = self,
			List = self.Connects,
			Connected = true
		}, {__index = ConnectionMethods})
		;(self.Connects :: any)[connection] = callback
		return connection
	else
		return nil
	end
end

function SignalMethods:ConnectWithLast(callback: (...any) -> ()): any
	local connection = self:Connect(callback)
	if connection and self.EverFired then
		local lastValues = self.LatestFiredValue :: {any}
		task.spawn(callback, table.unpack(lastValues))
	end
	return connection
end

function SignalMethods:ImmediateConnect(callback: (...any) -> ()): any
	if self.ImmediateConnects then
		local connection = setmetatable({
			Signal = self,
			List = self.ImmediateConnects,
			Connected = true
		}, {__index = ConnectionMethods})
		;(self.ImmediateConnects :: any)[connection] = callback
		return connection
	else
		return nil
	end
end

function SignalMethods:ImmediateConnectWithLast(callback: (...any) -> ()): any
	local connection = self:ImmediateConnect(callback)
	if connection and self.EverFired then
		local lastValues = self.LatestFiredValue :: {any}
		callback(table.unpack(lastValues))
	end
	return connection
end

function SignalMethods:Wait(): ...any
	if self.Waits then
		table.insert(self.Waits, coroutine.running())
		return coroutine.yield()
	else
		return nil
	end
end

function SignalMethods:WaitIfNeverFired(): ...any
	if self.EverFired then
		return if type(self.LatestFiredValue) == "table" then table.unpack(self.LatestFiredValue) else nil
	else
		return self:Wait()
	end
end

function SignalMethods:Fire(...: any)
	self.EverFired = true
	self.LatestFiredValue = {...}

	if self.ImmediateConnects then
		for _: any, c: (...any) -> () in pairs(self.ImmediateConnects) do
			c(...)
		end
	end
	if self.Connects then
		for _: any, c: (...any) -> () in pairs(self.Connects) do
			task.spawn(c, ...)
		end
	end
	if self.Waits then
		for _: number, t: thread in ipairs(self.Waits) do
			if coroutine.status(t) == "suspended" then
				coroutine.resume(t, ...)
			end
		end
		self.Waits = {}
	end
end

function SignalMethods:MassDisconnect()
	if self.Connects then
		for c: any, _: (...any) -> () in pairs(self.Connects) do
			c:Disconnect()
		end
		self.Connects = {}
	end
	if self.ImmediateConnects then
		for c: any, _: (...any) -> () in pairs(self.ImmediateConnects) do
			c:Disconnect()
		end
		self.ImmediateConnects = {}
	end
end

function SignalMethods:Destroy()
	self:MassDisconnect()
	if self.Waits then
		for _: number, t: thread in ipairs(self.Waits) do
			if coroutine.status(t) == "suspended" then
				coroutine.resume(t, nil)
			end
		end
	end
	self.Dead = true
	self.Connects = nil
	self.ImmediateConnects = nil
	self.Waits = nil :: any
	self.LatestFiredValue = nil
end

-- // CONSTRUCTORS //

function KapraoSignal.new(): AnySignal
	local self = setmetatable({
		Connects = {},
		ImmediateConnects = {},
		Waits = {},
		Dead = false,
		EverFired = false,
		LatestFiredValue = {nil}
	}, {__index = SignalMethods})
	return self :: any
end

table.freeze(KapraoSignal)
return KapraoSignal