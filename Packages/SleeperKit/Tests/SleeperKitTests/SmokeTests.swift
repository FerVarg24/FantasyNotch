import Testing

@testable import SleeperKit
@testable import SleeperKitMocks

@Suite("Smoke")
struct SmokeTests {
    @Test("el paquete expone su versión")
    func packageExposesVersion() {
        #expect(SleeperKit.version == "0.1.0")
    }

    @Test("el target de mocks enlaza con SleeperKit")
    func mocksLinkAgainstKit() {
        #expect(SleeperKitMocks.isAvailable)
    }
}
