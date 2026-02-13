/**
 * 测试工具类
 * 提供通用的测试辅助函数
 */
package mail_test.test_helpers

import std.collection.*

/**
 * 断言相等
 */
public func assertEqual<T>(actual: T, expected: T, message: String = ""): Unit where T <: Equatable<T> {
    if (actual != expected) {
        let msg = if (message.isEmpty()) {
            "断言失败: 期望 ${expected}, 实际 ${actual}"
        } else {
            "${message}: 期望 ${expected}, 实际 ${actual}"
        }
        throw AssertionError(msg)
    }
}

/**
 * 断言为真
 */
public func assertTrue(condition: Bool, message: String = ""): Unit {
    if (!condition) {
        let msg = if (message.isEmpty()) {
            "断言失败: 期望为 true"
        } else {
            "${message}: 期望为 true"
        }
        throw AssertionError(msg)
    }
}

/**
 * 断言为假
 */
public func assertFalse(condition: Bool, message: String = ""): Unit {
    if (condition) {
        let msg = if (message.isEmpty()) {
            "断言失败: 期望为 false"
        } else {
            "${message}: 期望为 false"
        }
        throw AssertionError(msg)
    }
}

/**
 * 断言为 None
 */
public func assertNone<T>(value: ?T, message: String = ""): Unit {
    if (value != None) {
        let msg = if (message.isEmpty()) {
            "断言失败: 期望为 None"
        } else {
            "${message}: 期望为 None"
        }
        throw AssertionError(msg)
    }
}

/**
 * 断言不为 None
 */
public func assertNotNone<T>(value: ?T, message: String = ""): Unit {
    if (value == None) {
        let msg = if (message.isEmpty()) {
            "断言失败: 期望不为 None"
        } else {
            "${message}: 期望不为 None"
        }
        throw AssertionError(msg)
    }
}

/**
 * 断言抛出异常
 */
public func assertThrows<E>(action: () -> Unit, message: String = ""): Unit where E <: Exception {
    var thrown = false
    try {
        action()
    } catch (e: E) {
        thrown = true
    }

    if (!thrown) {
        let msg = if (message.isEmpty()) {
            "断言失败: 期望抛出异常"
        } else {
            "${message}: 期望抛出异常"
        }
        throw AssertionError(msg)
    }
}

/**
 * 断言字符串包含
 */
public func assertContains(haystack: String, needle: String, message: String = ""): Unit {
    if (!haystack.contains(needle)) {
        let msg = if (message.isEmpty()) {
            "断言失败: '${haystack}' 应包含 '${needle}'"
        } else {
            "${message}: '${haystack}' 应包含 '${needle}'"
        }
        throw AssertionError(msg)
    }
}

/**
 * 断言数组相等
 */
public func assertArrayEqual<T>(actual: Array<T>, expected: Array<T>, message: String = ""): Unit where T <: Equatable<T> {
    if (actual.size != expected.size) {
        let msg = if (message.isEmpty()) {
            "断言失败: 数组长度不同, 期望 ${expected.size}, 实际 ${actual.size}"
        } else {
            "${message}: 数组长度不同, 期望 ${expected.size}, 实际 ${actual.size}"
        }
        throw AssertionError(msg)
    }

    for (i in 0..actual.size) {
        if (actual[i] != expected[i]) {
            let msg = if (message.isEmpty()) {
                "断言失败: 数组元素 [${i}] 不同, 期望 ${expected[i]}, 实际 ${actual[i]}"
            } else {
                "${message}: 数组元素 [${i}] 不同, 期望 ${expected[i]}, 实际 ${actual[i]}"
            }
            throw AssertionError(msg)
        }
    }
}

/**
 * 自定义断言错误
 */
public class AssertionError <: Exception {
    public init(message: String) {
        super(message)
    }
}

/**
 * 测试运行器
 */
public class TestRunner {
    private var testCount: Int = 0
    private var passedCount: Int = 0
    private var failedCount: Int = 0
    private var failedTests: ArrayList<String> = ArrayList<String>()

    /**
     * 运行测试
     */
    public func runTest(name: String, test: () -> Unit): Unit {
        testCount += 1
        print("[${testCount}] 运行测试: ${name} ... ")

        try {
            test()
            passedCount += 1
            println("✓ 通过")
        } catch (e: AssertionError) {
            failedCount += 1
            failedTests.add(name)
            println("✗ 失败")
            println("  错误: ${e.message}")
        } catch (e: Exception) {
            failedCount += 1
            failedTests.add(name)
            println("✗ 异常")
            println("  异常: ${e.message}")
        }
    }

    /**
     * 打印测试报告
     */
    public func printReport(): Unit {
        println("\n" + "=".repeat(60))
        println("测试报告")
        println("=".repeat(60))
        println("总计: ${testCount} 个测试")
        println("通过: ${passedCount} 个测试 (${passedCount * 100 / testCount}%)")
        println("失败: ${failedCount} 个测试 (${failedCount * 100 / testCount}%)")

        if (failedCount > 0) {
            println("\n失败的测试:")
            for (test in failedTests) {
                println("  - ${test}")
            }
        }

        println("=".repeat(60))
    }

    /**
     * 返回是否所有测试通过
     */
    public func allPassed(): Bool {
        return failedCount == 0
    }
}
