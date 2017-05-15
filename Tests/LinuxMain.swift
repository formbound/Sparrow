#if os(Linux)

import XCTest

@testable import RouterTests
@testable import SparrowTests

XCTMain([
    testCase(RouterTests.allTests),
    testCase(SparrowTests.allTests)
])

#endif
