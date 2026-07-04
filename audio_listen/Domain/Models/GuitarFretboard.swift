//
//  GuitarFretboard.swift
//  audio_listen
//
//  Deprecated shim over `Instruments.guitar` (the single source of truth).
//  Retained only so the not-yet-removed Random*Strategy files and their tests
//  compile; delete this together with them in the dead-code cleanup task.
//

import Foundation

struct GuitarFretboard {
    static var fretCount: Int { Instruments.guitar.fretCount }

    static func note(at string: Int, fret: Int) -> Note? {
        Instruments.guitar.note(at: string, fret: fret)
    }

    static func positions(for note: Note, maxFretInclusive: Int = Instruments.guitar.fretCount) -> [FretPosition] {
        Instruments.guitar.positions(for: note, maxFretInclusive: maxFretInclusive)
    }

    static var playableNotes: [Note] {
        let minMidi = Note(.e, octave: 2).midiNumber
        let maxMidi = Note(.e, octave: 5).midiNumber
        return (minMidi...maxMidi).compactMap { Note.from(midiNumber: $0) }
    }
}
