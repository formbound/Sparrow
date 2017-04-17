import Venice

public protocol Host {
    func accept(deadline: Deadline) throws -> Stream
}
