#if os(Linux)

import XCTest

@testable import IPTests
@testable import TCPTests
@testable import OpenSSLTests
@testable import POSIXTests

XCTMain([
    testCase(IPTests.allTests),
    testCase(TCPTests.allTests),
    testCase(POSIXTests.allTests),
])

#endif
