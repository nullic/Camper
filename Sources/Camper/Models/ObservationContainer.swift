import Foundation

public actor ObservationContainer<Value> {
    private var notificationObserver: NSObjectProtocol?
    private var observers = NSHashTable<ObservationToken<Value>>(options: .weakMemory)

    public init() {}

    public nonisolated func addObserver(onChange: @escaping ObservationToken<Value>.OnChange) -> ObservationToken<Value> {
        let token = ObservationToken<Value>(onChange: onChange) { [weak self] uuid in
            guard let self else { return }
            Task {
                await self._removeObserver(uuid: uuid)
            }
        }

        Task {
            await _addObserver(token)
        }

        return token
    }

    private func _addObserver(_ token: ObservationToken<Value>) {
        observers.add(token)
    }

    private func _removeObserver(uuid: UUID) {
        if let observer = observers.allObjects.first(where: { $0.uuid == uuid }) {
            observers.remove(observer)
        }
    }

    public nonisolated func notifyObservers() where Value == Void {
        Task {
            await _notifyObservers(value: Void())
        }
    }

    public nonisolated func notifyObservers(value: Value) where Value: Sendable {
        Task {
            await _notifyObservers(value: value)
        }
    }

    public func notifyObservers(value: Value) async {
        await _notifyObservers(value: value)
    }

    private func _notifyObservers(value: Value) async {
        for observer in observers.allObjects {
            observer.notify(value: value)
        }
    }
}
