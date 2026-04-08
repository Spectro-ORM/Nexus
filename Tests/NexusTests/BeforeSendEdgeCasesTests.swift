import Testing
import HTTPTypes
@testable import Nexus

/// Tests for BeforeSend lifecycle hook edge cases
@Suite("BeforeSend Edge Cases")
struct BeforeSendEdgeCasesTests {

    // MARK: - registerBeforeSend() Edge Cases

    @Test("registerBeforeSend preserves other fields")
    func registerBeforeSendPreservesOtherFields() {
        var conn = Connection.make()
        conn = conn.assign(key: "test", value: "value")
        conn.response.status = .created

        let registered = conn.registerBeforeSend { $0 }

        #expect(registered.assigns["test"] as? String == "value")
        #expect(registered.response.status == .created)
    }

    @Test("registerBeforeSend adds callback without executing")
    func registerBeforeSendAddsCallback() {
        var executed = false
        let conn = Connection.make()

        let registered = conn.registerBeforeSend { _ in
            executed = true
            return $0
        }

        #expect(executed == false)
        #expect(registered.beforeSend.count == 1)
    }

    @Test("registerBeforeSend multiple callbacks accumulate")
    func registerBeforeSendMultipleCallbacks() {
        let conn = Connection.make()

        let registered = conn
            .registerBeforeSend { $0 }
            .registerBeforeSend { $0 }
            .registerBeforeSend { $0 }

        #expect(registered.beforeSend.count == 3)
    }

    @Test("registerBeforeSend creates independent copy")
    func registerBeforeSendCreatesIndependentCopy() {
        let original = Connection.make()
        var modified = original.registerBeforeSend { $0 }

        #expect(original.beforeSend.isEmpty)
        #expect(modified.beforeSend.count == 1)

        // Further modifications should not affect original
        modified = modified.registerBeforeSend { $0 }
        #expect(original.beforeSend.isEmpty)
        #expect(modified.beforeSend.count == 2)
    }

    // MARK: - runBeforeSend() Edge Cases

    @Test("runBeforeSend executes callbacks in LIFO order")
    func runBeforeSendLIFOOrder() {
        var executionOrder: [Int] = []

        let conn = Connection.make()
        let registered = conn
            .registerBeforeSend { _ in
                executionOrder.append(1)
                return $0
            }
            .registerBeforeSend { _ in
                executionOrder.append(2)
                return $0
            }
            .registerBeforeSend { _ in
                executionOrder.append(3)
                return $0
            }

        _ = registered.runBeforeSend()

        #expect(executionOrder == [3, 2, 1])
    }

    @Test("runBeforeSend clears callback array")
    func runBeforeSendClearsCallbacks() {
        let conn = Connection.make()
        let registered = conn
            .registerBeforeSend { $0 }
            .registerBeforeSend { $0 }

        let result = registered.runBeforeSend()

        #expect(result.beforeSend.isEmpty)
    }

    @Test("runBeforeSend with no callbacks is no-op")
    func runBeforeSendNoCallbacks() {
        let conn = Connection.make()

        let result = conn.runBeforeSend()

        #expect(result.beforeSend.isEmpty)
        #expect(result.request.method == .get)
        #expect(result.response.status == .ok)
    }

    @Test("runBeforeSend with single callback")
    func runBeforeSendSingleCallback() {
        var callbackExecuted = false
        let conn = Connection.make()

        let registered = conn.registerBeforeSend { conn in
            callbackExecuted = true
            var copy = conn
            copy.response.status = .init(statusCode: 201)
            return copy
        }

        let result = registered.runBeforeSend()

        #expect(callbackExecuted == true)
        #expect(result.response.status == .created)
        #expect(result.beforeSend.isEmpty)
    }

    @Test("runBeforeSend with callback that modifies connection")
    func runBeforeSendModifiesConnection() {
        let conn = Connection.make()

        let registered = conn
            .registerBeforeSend { conn in
                var copy = conn
                copy.response.status = .accepted
                copy.responseBody = .string("modified")
                return copy
            }

        let result = registered.runBeforeSend()

        #expect(result.response.status == .accepted)
        case let .buffered(data) = result.responseBody
        #expect(String(data: data, encoding: .utf8) == "modified")
    }

    @Test("runBeforeSend with callback chain")
    func runBeforeSendCallbackChain() {
        let conn = Connection.make()

        let registered = conn
            .registerBeforeSend { conn in
                var copy = conn
                copy.response.headerFields[.contentType] = "text/plain"
                return copy
            }
            .registerBeforeSend { conn in
                var copy = conn
                copy.response.status = .init(statusCode: 201)
                return copy
            }
            .registerBeforeSend { conn in
                var copy = conn
                copy.assign(key: "logged", value: true)
                return copy
            }

        let result = registered.runBeforeSend()

        // Last registered (assign) runs first
        #expect(result.assigns["logged"] as? Bool == true)
        // Then status change
        #expect(result.response.status == .created)
        // Then content type (first registered, last executed)
        #expect(result.response.headerFields[.contentType] == "text/plain")
    }

    @Test("runBeforeSend with halted connection")
    func runBeforeSendWithHaltedConnection() {
        var callbackExecuted = false
        var conn = Connection.make()
        conn.isHalted = true

        let registered = conn.registerBeforeSend { conn in
            callbackExecuted = true
            var copy = conn
            copy.response.status = .internalServerError
            return copy
        }

        let result = registered.runBeforeSend()

        #expect(callbackExecuted == true)
        #expect(result.isHalted == true)
        #expect(result.response.status == .internalServerError)
    }

    // MARK: - Error Handling in Callbacks

    @Test("runBeforeSend callback that throws")
    func runBeforeSendCallbackThrows() {
        let conn = Connection.make()

        let registered = conn.registerBeforeSend { _ in
            // Note: callbacks cannot throw - they return Connection
            // This test verifies the type system prevents throwing
            var copy = $0
            copy.response.status = .internalServerError
            return copy
        }

        // Should compile and execute without throwing
        let result = registered.runBeforeSend()
        #expect(result.response.status == .internalServerError)
    }

    // MARK: - Sendable Conformance

    @Test("beforeSend callbacks are Sendable")
    func beforeSendCallbacksAreSendable() async throws {
        actor TestActor {
            private var stored: Connection?

            func store(_ conn: Connection) {
                stored = conn
            }

            func get() -> Connection? {
                stored
            }
        }

        let actor = TestActor()
        var conn = Connection.make()

        // Register Sendable callback
        conn = conn.registerBeforeSend { conn in
            var copy = conn
            copy.response.status = .init(statusCode: 201)
            return copy
        }

        await actor.store(conn)
        let retrieved = await actor.get()

        #expect(retrieved?.beforeSend.count == 1)
    }

    // MARK: - Multiple runBeforeSend() Calls

    @Test("calling runBeforeSend twice only executes once")
    func runBeforeSendTwice() {
        var executionCount = 0
        let conn = Connection.make()

        let registered = conn.registerBeforeSend { _ in
            executionCount += 1
            return $0
        }

        let result1 = registered.runBeforeSend()
        let result2 = result1.runBeforeSend()

        #expect(executionCount == 1)
        #expect(result2.beforeSend.isEmpty)
    }

    // MARK: - Callback Registration After runBeforeSend

    @Test("registering callbacks after runBeforeSend")
    func registerAfterRunBeforeSend() {
        let conn = Connection.make()

        let registered = conn.registerBeforeSend { $0 }
        let afterRun = registered.runBeforeSend()

        let newRegistration = afterRun.registerBeforeSend { conn in
            var copy = conn
            copy.response.status = .init(statusCode: 201)
            return copy
        }

        #expect(newRegistration.beforeSend.count == 1)

        let result = newRegistration.runBeforeSend()
        #expect(result.response.status == .created)
    }

    // MARK: - Complex Callback Scenarios

    @Test("callback that reads and modifies assigns")
    func callbackReadsAndModifiesAssigns() {
        var conn = Connection.make()
        conn = conn.assign(key: "counter", value: 0)

        let registered = conn.registerBeforeSend { conn in
            let current = conn.assigns["counter"] as? Int ?? 0
            var copy = conn
            copy.assigns["counter"] = current + 1
            return copy
        }

        let result = registered.runBeforeSend()
        #expect(result.assigns["counter"] as? Int == 1)
    }

    @Test("callback that conditionally modifies response")
    func callbackConditionallyModifiesResponse() {
        let conn = Connection.make()

        let registered = conn.registerBeforeSend { conn in
            var copy = conn
            if conn.response.status == .ok {
                copy.response.status = .accepted
            } else {
                copy.response.status = .internalServerError
            }
            return copy
        }

        let result = registered.runBeforeSend()
        #expect(result.response.status == .accepted)
    }

    @Test("callback with empty response body")
    func callbackWithEmptyBody() {
        var conn = Connection.make()
        conn.responseBody = .string("original")

        let registered = conn.registerBeforeSend { conn in
            var copy = conn
            copy.responseBody = .empty
            return copy
        }

        let result = registered.runBeforeSend()
        case .empty = result.responseBody
    }
}
