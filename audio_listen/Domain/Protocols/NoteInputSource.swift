import Combine

protocol NoteInputSource: AnyObject {
    var notes: AnyPublisher<Note, Never> { get }
    func start() throws
    func stop()
}
