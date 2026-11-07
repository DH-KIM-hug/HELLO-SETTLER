# Threading (WorkerThreadPool, thread safety)

Last verified: 2026-11-07
Sources: https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html, https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html

## WorkerThreadPool
- `add_task(action: Callable, high_priority = false, description = "") -> int`; `add_group_task(action, elements, tasks_needed = -1, high_priority = false, description = "") -> int` (action receives indices 0..elements-1).
- `wait_for_task_completion(task_id) -> Error`: `OK`; `ERR_INVALID_PARAMETER` if no such task (e.g. already awaited); `ERR_BUSY` if waiting could deadlock (waiting on an older task lower in the call stack).
- Every task must eventually be awaited ("wait_for_task_completion" or "wait_for_group_task_completion") so resources are cleaned up. `is_task_completed` only between add and await. `get_caller_task_id()` returns -1 for group tasks, invalid callers and the main thread.
- Group example assumes the element count is constant while running. "Offloading cheap work can hurt performance."
- Changes in 4.4-4.7: none documented on the class page, none listed in the upgrade guides.

## Thread safety (thread_safe_apis.html)
- "Interacting with the active scene tree is not thread-safe." Build off-tree node trees on a thread, add them with `call_deferred`.
- "Modifying a unique resource from multiple threads is not supported." Passing references between threads is supported.
- Global-scope singletons are thread-safe by default; "Accessing servers from threads is supported." Rendering nodes are not thread-safe by default. Physics is not thread-safe by default. Navigation servers are thread-safe.
- GDScript containers: reading/writing elements from multiple threads is fine; size-changing operations (resize/add/remove) need a mutex.
- `call_deferred` / `set_deferred` for calling back into the scene.
- RefCounted: NOT SOURCEABLE — the page does not mention RefCounted. Whether reference-count updates or typed RefCounted sim objects are safe to share across worker threads is not stated. Inference only: the page's resource rule (no concurrent modification of a unique resource) suggests keeping each RefCounted sim object owned by one thread at a time; not stated by the docs.
- Note: `Mutex`/`Semaphore`: `Semaphore.post` gained optional `count` in 4.4.
