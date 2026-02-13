/**
 * 测试套件主入口
 * 运行所有单元测试
 */
package mail_test

import mail_test.core.*
import mail_test.internet.*
import mail_test.test_helpers.*

/**
 * 运行所有测试模块
 */
main(): Int64 {
    println("━".repeat(70))
    println("  Cangjie Mail 单元测试套件")
    println("━".repeat(70))
    println()

    var totalPassed = 0
    var totalFailed = 0
    let failedModules = ArrayList<String>()

    // 测试模块列表
    let testModules = [
        ("Core - Session", core.session_test.runAllTests),
        ("Internet - InternetAddress", internet.internet_address_test.runAllTests),
        ("Internet - MimeUtility", internet.mime_utility_test.runAllTests),
    ]

    for ((name, testFunc) in testModules) {
        println("\n┌─ 运行模块: ${name}")
        println("└─" + "─".repeat(66))

        try {
            testFunc()
            totalPassed += 1
            println("   ✓ 模块测试通过\n")
        } catch (e: Exception) {
            totalFailed += 1
            failedModules.add(name)
            println("   ✗ 模块测试失败: ${e.message}\n")
        }
    }

    // 打印总结
    println("━".repeat(70))
    println("  测试总结")
    println("━".repeat(70))
    println("  总计模块: ${totalPassed + totalFailed}")
    println("  通过模块: ${totalPassed} (${totalPassed * 100 / (totalPassed + totalFailed)}%)")
    println("  失败模块: ${totalFailed} (${totalFailed * 100 / (totalPassed + totalFailed)}%)")

    if (totalFailed > 0) {
        println("\n  失败的模块:")
        for (module in failedModules) {
            println("    ✗ ${module}")
        }
    }

    println("━".repeat(70))

    if (totalFailed > 0) {
        return 1
    }

    println("\n✓ 所有测试通过！\n")
    return 0
}
