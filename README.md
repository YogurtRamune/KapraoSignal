# KapraoSignal V3

A strict Luau module for handling events/signals

Made specifically for Roblox development

Pros

* **Strict Typing:** Full support for Luau generics (`Signal<string, number>`).

* **Execution Control:** Has a separation between immediate connect (`Signal:ImmediateConnect()`) and the conventional connect (`Signal:Connect()`).

* **State Awareness:** Supports waiting if a signal is never fired (`Signal:WaitIfNeverFired()`).

* **Late Subscriptions:** Supports connecting with the last fired value (`Signal:ConnectWithLast()` and `Signal:ImmediateConnectWithLast()`).

* **Safety:** `Wait` is resumed and nil is passed if a `Signal` is destroyed or being destroyed while waiting.

Cons

* Reconnection isn't supported.

* No wrapper for Roblox's RBXScriptSignal constructor.

* Not optimized for extreme high-frequency benchmarking (priority is safety and features).

### Strict Typing & Annotations

For those who want full Luau type checking and autocomplete support, KapraoSignal exports three distinct types.

**1. Standard Typing (`Signal<T...>`)** - *Recommended*
Infers the callback signature directly from the arguments you define.

```luau
local KapraoSignal = require(path.to.KapraoSignal)

-- Create a signal that ONLY accepts a string and a number
local HealthChanged = KapraoSignal.new() :: KapraoSignal.Signal<string, number>

HealthChanged:Connect(function(name, health)
    -- Autocomplete knows 'name' is string, 'health' is number
end)
```

**2. Explicit Handler Typing (`ExplicitSignal<U, V...>`)**
Use this if you have a defined function type alias.

```luau
type MyHandler = (string, number) -> ()
local MySignal = KapraoSignal.new() :: KapraoSignal.ExplicitSignal<(parameter1: string, parameter2: number), string, number>
```

**3. Dynamic Typing (`AnySignal`)** - *Default*
Accepts any arguments (loose typing).

```luau
local MySignal = KapraoSignal.new() -- Returns AnySignal by default
```

### KapraoSignal

```luau
KapraoSignal.new() -> Signal<...any>
```

### Signal

```luau
Signal.Dead : boolean
```

Status of a signal if it's destroyed for not. If the state is true, Connections are disconnected and Waits are continued with nil value passed

```luau
Signal.EverFired : boolean
```

Status of a signal if `Signal:Fire()` has ever been invoked. The latest variadic arguments passed to `Signal:Fire()` will be stored in `Signal.LatestFiredValue`

```luau
Signal.LatestFiredValue : {any}
```

Latest variadic arguments passed to `Signal:Fire()` and packed directly (`{...}` not `table.pack(...)`).
If no arguments were passed then it'll return an empty table (`{}`)

```luau
Signal:ImmediateConnect(callback: (T...) -> ()) -> Connection?
```

If the signal isn't Destroyed/Dead, `Connection` will be returned. Otherwise, `nil`.
Has the most priority and will run in the same thread where its signal is fired.
Errors in callbacks are caught via `pcall` and re-thrown in a separate thread, so a failing callback won't halt other connections or waits.

```luau
Signal:ImmediateConnectWithLast(callback: (T...) -> ()) -> Connection?
```

Acts exactly like `Signal:ImmediateConnect()`, but if `Signal.EverFired` is true, the callback will be invoked **synchronously** with `Signal.LatestFiredValue` immediately after connecting.

```luau
Signal:Once(callback: (T...) -> ()) -> Connection?
```

Like `Signal:Connect()`, but automatically disconnects after the callback is invoked once.
Returns the `Connection` so it can be cancelled before it fires.
If the signal is dead, returns `nil`.

```luau
Signal:Connect(callback: (T...) -> ()) -> Connection?
```

If the signal isn't Destroyed/Dead, `Connection` will be returned. Otherwise, `nil`.
After the signal is fired, the callback will be run through `task.spawn` after immediate connections' callback

```luau
Signal:ConnectWithLast(callback: (T...) -> ()) -> Connection?
```

Acts exactly like `Signal:Connect()`, but if `Signal.EverFired` is true, the callback will be spawned **asynchronously** (via `task.spawn`) with `Signal.LatestFiredValue` immediately after connecting.

```luau
Signal:Wait() -> (T...)?
```

Yields the current thread unless the signal is already dead it'll return nil instead.
Returns any variadic arguments passed to `Signal:Fire()` unless the signal is being destroyed while waiting

```luau
Signal:WaitIfNeverFired() -> (T...)?
```

Similar to `Signal:Wait()` but if `Signal.EverFired` is true, then `table.unpack(Signal.LatestFiredValue)` will be returned immediately

```luau
Signal:Fire(Args...)
```

Triggers connections' callbacks and the variadic arguments are passed to those callbacks.
Waits are resumed returning the passed variadic arguments. if a thread's status is not `suspended` then that thread will be skipped
If the signal is already destroyed/dead this method won't do anything.

```luau
Signal:MassDisconnect()
```

Disconnects every connections but waits are not resumed and left yielding/suspended.
However new connections and waits are still permitted

```luau
Signal:Destroy()
```

Disconnects every connections, resumes every Waits with nil passed to those threads and sets `Signal.Dead` to true.
Preventing any new connections (Any connect methods in `Signal` will return nil instead of a `Connection`) and `Signal:Wait()` will never yield and always return nil

### Connection

```luau
Connection.Connected : boolean
```

Status of the connection if it is still connected to a signal or not

```luau
Connection.Signal : Signal?
```

The signal that the connection is connected to, could be nil in case the connection is disconnected

```luau
Connection:Disconnect()
```

Disconnects from the signal, hence preventing its callback from being invoked after its signal is fired.
Set its `Connection.Connected` to false and `Connection.Signal` to nil