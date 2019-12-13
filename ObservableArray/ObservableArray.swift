//
//  ObservableArray.swift
//  ObservableArray
//
//  Created by Safx Developer on 2015/02/19.
//  Copyright (c) 2016 Safx Developers. All rights reserved.
//

import Foundation
import RxSwift

public struct ArrayChangeTuple<Element> {
    public let insertedIndices: [(index: Int, element: Element)]
    public let deletedIndices: [(index: Int, element: Element)]
    public let updatedIndices: [(index: Int, element: Element)]
    
    var hasInserts: Bool { return insertedIndices.count > 0 }
    var hasUpdates: Bool { return updatedIndices.count > 0 }
    var hasDeletes: Bool { return deletedIndices.count > 0 }

    fileprivate init(inserted: [(index: Int, element: Element)] = [], deleted: [(index: Int, element: Element)] = [], updated: [(index: Int, element: Element)] = []) {
        insertedIndices = inserted
        deletedIndices = deleted
        updatedIndices = updated
    }
}

public struct ArrayChangeEvent {
    public let insertedIndices: [Int]
    public let deletedIndices: [Int]
    public let updatedIndices: [Int]
    
    var hasInserts: Bool { return insertedIndices.count > 0 }
    var hasUpdates: Bool { return updatedIndices.count > 0 }
    var hasDeletes: Bool { return deletedIndices.count > 0 }

    fileprivate init(inserted: [Int] = [], deleted: [Int] = [], updated: [Int] = []) {
        insertedIndices = inserted
        deletedIndices = deleted
        updatedIndices = updated
    }
}

public struct ObservableArray<Element>: ExpressibleByArrayLiteral {
    public typealias EventType = ArrayChangeEvent
    public typealias EventTuple = ArrayChangeTuple

    internal var eventSubject: BehaviorSubject<EventType>!
    internal var elementsSubject: BehaviorSubject<[Element]>!
    internal var tuplesSubject: BehaviorSubject<EventTuple<Element>>!
    internal var elements: [Element]

    public init() {
        elements = []
    }

    public init(count: Int, repeatedValue: Element) {
        elements = Array(repeating: repeatedValue, count: count)
    }

    public init<S : Sequence>(_ s: S) where S.Iterator.Element == Element {
        elements = Array(s)
    }

    public init(arrayLiteral elements: Element...) {
        self.elements = elements
    }
}

extension ObservableArray {
    public mutating func rx_elements() -> Observable<[Element]> {
        if elementsSubject == nil {
            elementsSubject = BehaviorSubject<[Element]>(value: elements)
        }
        return elementsSubject
    }

    public mutating func rx_events() -> Observable<EventType> {
        if eventSubject == nil {
            if elements.count > 0 {
                eventSubject = BehaviorSubject<EventType>(value: ArrayChangeEvent(inserted: Array(0..<elements.count), deleted: [], updated: []))
            } else {
                eventSubject = BehaviorSubject<EventType>(value: ArrayChangeEvent(inserted: [], deleted: [], updated: []))
            }
        }
        return eventSubject
    }
    
    public mutating func rx_tuples() -> Observable<EventTuple<Element>> {
        if tuplesSubject == nil {
            if elements.count > 0 {
                tuplesSubject = BehaviorSubject<EventTuple>(value: ArrayChangeTuple(inserted: elements.enumerated().map({ ($0, $1) }), deleted: [], updated: []))
            } else {
                tuplesSubject = BehaviorSubject<EventTuple>(value: ArrayChangeTuple(inserted: [], deleted: [], updated: []))
            }
        }
        return tuplesSubject
    }

    fileprivate func arrayDidChange(_ event: EventType) {
        elementsSubject?.onNext(elements)
        eventSubject?.onNext(event)
    }
    
    fileprivate func arrayDidChange(_ tuples: EventTuple<Element>) {
        tuplesSubject?.onNext(tuples)
    }
}

extension ObservableArray: Collection {
    public var capacity: Int {
        return elements.capacity
    }

    /*public var count: Int {
        return elements.count
    }*/

    public var startIndex: Int {
        return elements.startIndex
    }

    public var endIndex: Int {
        return elements.endIndex
    }

    public func index(after i: Int) -> Int {
        return elements.index(after: i)
    }
    
    /// Trigger the change event `update` for the given index
    /// - Parameter i: Index of element
    public func didChange(index i: Int) {
        arrayDidChange(ArrayChangeEvent(updated: [i]))
    }
}

extension ObservableArray: MutableCollection {
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        elements.reserveCapacity(minimumCapacity)
    }

    public mutating func append(_ newElement: Element) {
        elements.append(newElement)
        arrayDidChange(ArrayChangeEvent(inserted: [elements.count - 1]))
        arrayDidChange(ArrayChangeTuple(inserted: [(elements.count - 1, newElement)]))
    }

    public mutating func append<S : Sequence>(contentsOf newElements: S) where S.Iterator.Element == Element {
        let end = elements.count
        elements.append(contentsOf: newElements)
        guard end != elements.count else {
            return
        }
        arrayDidChange(ArrayChangeEvent(inserted: Array(end..<elements.count)))
        arrayDidChange(ArrayChangeTuple(inserted: newElements.enumerated().map({ ($0, $1) })))
    }

    public mutating func appendContentsOf<C : Collection>(_ newElements: C) where C.Iterator.Element == Element {
        guard !newElements.isEmpty else {
            return
        }
        let end = elements.count
        elements.append(contentsOf: newElements)
        arrayDidChange(ArrayChangeEvent(inserted: Array(end..<elements.count)))
        arrayDidChange(ArrayChangeTuple(inserted: newElements.enumerated().map({ ($0, $1) })))
    }

    @discardableResult public mutating func removeLast() -> Element {
        let e = elements.removeLast()
        arrayDidChange(ArrayChangeEvent(deleted: [elements.count]))
        arrayDidChange(ArrayChangeTuple(deleted: [(elements.count, e)]))
        return e
    }

    public mutating func insert(_ newElement: Element, at i: Int) {
        elements.insert(newElement, at: i)
        arrayDidChange(ArrayChangeEvent(inserted: [i]))
        arrayDidChange(ArrayChangeTuple(inserted: [(i, newElement)]))
    }

    @discardableResult public mutating func remove(at index: Int) -> Element {
        let e = elements.remove(at: index)
        arrayDidChange(ArrayChangeEvent(deleted: [index]))
        arrayDidChange(ArrayChangeTuple(deleted: [(index, e)]))
        return e
    }

    public mutating func removeAll(_ keepCapacity: Bool = false) {
        guard !elements.isEmpty else {
            return
        }
        let es = elements
        elements.removeAll(keepingCapacity: keepCapacity)
        arrayDidChange(ArrayChangeEvent(deleted: Array(0..<es.count)))
        arrayDidChange(ArrayChangeTuple(inserted: es.enumerated().map({ ($0, $1) })))
    }

    public mutating func insertContentsOf(_ newElements: [Element], atIndex i: Int) {
        guard !newElements.isEmpty else {
            return
        }
        elements.insert(contentsOf: newElements, at: i)
        arrayDidChange(ArrayChangeEvent(inserted: Array(i..<i + newElements.count)))
        arrayDidChange(ArrayChangeTuple(inserted: zip(Array(i..<i + newElements.count), newElements).map({ ($0, $1) })))
    }

    public mutating func popLast() -> Element? {
        if let e = elements.popLast() {
            arrayDidChange(ArrayChangeEvent(deleted: [elements.count]))
            arrayDidChange(ArrayChangeTuple(deleted: [(elements.count, e)]))
            return e
        }
        return nil
    }
}

extension ObservableArray: RangeReplaceableCollection {
    public mutating func replaceSubrange<C : Collection>(_ subRange: Range<Int>, with newCollection: C) where C.Iterator.Element == Element {
        let oldCount = elements.count
        let oldElements = elements
        elements.replaceSubrange(subRange, with: newCollection)
        let first = subRange.lowerBound
        let newCount = elements.count
        let end = first + (newCount - oldCount) + subRange.count
        arrayDidChange(ArrayChangeEvent(inserted: Array(first..<end), deleted: Array(subRange.lowerBound..<subRange.upperBound)))
        arrayDidChange(ArrayChangeTuple(inserted: zip(Array(first..<end), newCollection).map({ ($0, $1) }), deleted: zip(Array(subRange.lowerBound..<subRange.upperBound), oldElements).map({ ($0, $1) }))
        )
    }
}

extension ObservableArray: CustomDebugStringConvertible {
    public var description: String {
        return elements.description
    }
}

extension ObservableArray: CustomStringConvertible {
    public var debugDescription: String {
        return elements.debugDescription
    }
}

extension ObservableArray: Sequence {

    public subscript(index: Int) -> Element {
        get {
            return elements[index]
        }
        set {
            elements[index] = newValue
            if index == elements.count {
                arrayDidChange(ArrayChangeEvent(inserted: [index]))
                arrayDidChange(ArrayChangeTuple(inserted: [(index, newValue)]))
            } else {
                arrayDidChange(ArrayChangeEvent(updated: [index]))
                arrayDidChange(ArrayChangeTuple(updated: [(index, newValue)]))
            }
        }
    }

    public subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        get {
            return elements[bounds]
        }
        set {
            let oldElements = elements[bounds]
            elements[bounds] = newValue
            let first = bounds.lowerBound
            arrayDidChange(ArrayChangeEvent(inserted: Array(first..<first + newValue.count), deleted: Array(bounds.lowerBound..<bounds.upperBound)))
            arrayDidChange(ArrayChangeTuple(inserted: zip(Array(first..<first + newValue.count), newValue).map({ ($0, $1) }), deleted: zip(Array(bounds.lowerBound..<bounds.upperBound), oldElements).map({ ($0, $1) })))
        }
    }
}
