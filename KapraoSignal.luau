--!strict

local KapraoSignal = {}

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

export type Connection = typeof(setmetatable({} :: {
	Connected: boolean,
	Signal: any,
	List: {[Connection]: (...any) -> ()}?
}, {__index = ConnectionMethods}))

local SignalMethods = {}
function SignalMethods:Connect(callback: (...any) -> ()): Connection?
	if self.Connects then
		local connection: Connection = setmetatable({
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
function SignalMethods:ImmediateConnect(callback: (...any) -> ()): Connection?
	if self.ImmediateConnects then
		local connection: Connection = setmetatable({
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
function SignalMethods:Wait(): (...any?)
	if self.Waits then
		table.insert(self.Waits, coroutine.running())
		return coroutine.yield()
	else
		return nil
	end
end
function SignalMethods:WaitIfNeverFired(): (...any?)
	if self.EverFired then
		return if type(self.LastestFiredValue) == "table" then table.unpack(self.LastestFiredValue) else nil
	else
		return self:Wait()
	end
end
function SignalMethods:Fire(...: any)
	self.EverFired = true
	self.LastestFiredValue = {...}
	if self.ImmediateConnects then
		for _: Connection, c: (...any) -> () in pairs(self.ImmediateConnects) do
			c(...)
		end
	end
	if self.Connects then
		for _: Connection, c: (...any) -> () in pairs(self.Connects) do
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
		for c: Connection, _: (...any) -> () in pairs(self.Connects) do
			c:Disconnect()
		end
		self.Connects = {}
	end
	if self.ImmediateConnects then
		for c: Connection, _: (...any) -> () in pairs(self.ImmediateConnects) do
			c:Disconnect()
		end
		self.ImmediateConnects = {}
	end
end
function SignalMethods:Destroy()
	for c: Connection, _: (...any) -> () in pairs(self.Connects) do
		c:Disconnect()
	end
	for c: Connection, _: (...any) -> () in pairs(self.ImmediateConnects) do
		c:Disconnect()
	end
	for _: number, t: thread in ipairs(self.Waits) do
		if coroutine.status(t) == "suspended" then
			coroutine.resume(t, nil)
		end
	end
	self.Dead = true
	(self :: {Connects: any?}).Connects = nil
	(self :: {ImmediateConnects: any?}).ImmediateConnects = nil
	(self :: {Waits: any?}).Waits = nil
end

export type Signal = typeof(setmetatable({} :: {
	Connects: {[Connection]: (...any) -> ()}?,
	ImmediateConnects: {[Connection]: (...any) -> ()}?,
	Waits: {thread}?,
	Dead: boolean,
	EverFired: boolean,
	LastestFiredValue: {any}
}, {__index = SignalMethods}))

KapraoSignal.new = function(): Signal
	return setmetatable({
		Connects = {},
		ImmediateConnects = {},
		Waits = {},
		Dead = false,
		EverFired = false,
		LastestFiredValue = {nil}
	}, {__index = SignalMethods})
end

table.freeze(KapraoSignal)
return KapraoSignal
