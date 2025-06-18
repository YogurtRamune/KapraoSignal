# KapraoSignal V1
A luau module for handling events/signals\
Made specifically for roblox development

Pros
- Has a seperation between immediate connect (`Signal:ImmediateConnect()`) and the conventional connect (`Signal:Connect()`)
- Supports wait if a signal is never fired (`Signal:WaitIfNeverFired()`)
- Wait is resumed and nil is passed if a `Signal` is destroyed or being destroyed while waiting

Cons
- No `Once` connection yet (may be implemented in the future)
- Reconnection isn't supported
- No wrap Roblox's signals constructor
- Not optimized and never profiled or benchmark

Possible features that may be added in future versions:
- Supports `Once` connections
- Priorotize immediate connections' callback invoke order through `Priority` value in `Connection`s

### KapraoSignal
```lua
KapraoSignal.new() -> Signal
```
### Signal
```lua
Signal.Dead : boolean
```
Status of a signal if it's destroyed for not. If the state is true, Connections are disconnected and Waits are continued with nil value passed
<br/><br/>

```lua
Signal.EverFired : boolean
```
Status of a signal if `Signal:Fire()` has ever been invoked. the lastest variadic arguments passed to `Signal:Fire()` will be stored in `Signal.LastestFiredValue`
<br/><br/>

```lua
Signal.LastestFiredValue : {any}
```
Lastest variadic arguments passed to `Signal:Fire()` and packed directly (`{...}` not `table.pack(...)`).
If no arguments were passed then it'll return an empty table (`{}`)
<br/><br/>

```lua
Signal:ImmediateConnect(callback: (...any) -> ()) -> Connection?
```
If the signal isn't Destroyed/Dead, `Connection` will be returned. Otherwise, `nil`.
Has the most priority and will run in the same thread where its signal is fired.
Be cautious while using this method as it can interrupt the thread where signal is fired if there's any error in any callbacks
<br/><br/>

```lua
Signal:Connect(callback: (...any) -> ()) -> Connection?
```
If the signal isn't Destroyed/Dead, `Connection` will be returned. Otherwise, `nil`.
After the signal is fired, the callback will be run through `task.spawn` after immediate connections' callback
<br/><br/>

```lua
Signal:Wait() -> (...any)?
```
Yields the current thread unless the signal is already dead it'll return nil instead.
Returns any variadic arguments passed to `Signal:Fire()` unless the signal is being destroyed while waiting
<br/><br/>

```lua
Signal:WaitIfNeverFired() -> (...any)?
```
Similar to `Signal:Wait()` but if `Signal.EverFired` is true, then `table.unpack(Signal.LastestFiredValue)` will be returned immedietly
<br/><br/>

```lua
Signal:Fire(...: any)
```
Triggers connections' callbacks and the variadic arguments are passed to those callbacks.
Waits are resumed returning the passed variadic arguments. if a thread's status is not `suspended` then that thread will be skipped
If the signal is already destroyed/dead this method won't do anything.
<br/><br/>

```lua
Signal:MassDisconnect()
```
Disconnects every connections but waits are not resumed and left yielding/suspended.
However new connections and waits are still permitted
<br/><br/>

```lua
Signal:Destroy()
```
Disconnects every connections, resumes every Waits with nil passed to those threads and sets `Signal.Dead` to true.
Preventing any new connections (Any connect methods in `Signal` will return nil instead of a `Connection`) and `Signal:Wait()` will never yield always return nil
<br/><br/>

### Connection
```lua
Connection.Connected : boolean
```
Status of the connection if it is still connected to a signal or not
<br/><br/>

```lua
Connection.Signal : Signal?
```
The signal that the connection is connected to, could be nil in case the connection is disconnected
<br/><br/>

```lua
SignalMethods:Disconnect()
```
Disconnects from the signal, hence preventing its callback from being invoked after its signal is fired.
Set its `Connection.Connected` to false and `Connection.Signal` to nil
