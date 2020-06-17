//
//  IntegerLowerBound.swift
//  GAEN_Explorer
//
//  Created by Bill on 6/13/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import Foundation

struct BoundedInt: Equatable, ExpressibleByIntegerLiteral, CustomStringConvertible, Codable, Hashable, LosslessStringConvertible {
    init?(_: String) {
        assert(false)
        self.lb = 0
        self.ub = BoundedInt.infinity
    }

    static let unknown = BoundedInt(0, BoundedInt.infinity)
    static let infinity = 999
    let lb: Int
    let ub: Int
    var center: Int {
        if ub == BoundedInt.infinity {
            return ub
        }
        return (lb + ub) / 2
    }

    var isNearlyExact: Bool {
        ub != BoundedInt.infinity && lb == ub
    }

    var isLowerBound: Bool {
        ub == BoundedInt.infinity
    }

    init(exact: Int) {
        self.lb = exact
        self.ub = exact
    }

    init(integerLiteral value: IntegerLiteralType) {
        if value == 0 {
            self.lb = 0
            self.ub = 0
        } else
        if value >= 30 {
            self.lb = 30
            self.ub = BoundedInt.infinity
        } else {
            self.lb = value
            self.ub = value
        }
    }

    init(_ value: Int) {
        if value == 0 {
            self.lb = 0
            self.ub = 0
        } else
        if value >= 30 {
            self.lb = 30
            self.ub = BoundedInt.infinity
        } else {
            self.lb = value
            self.ub = value
        }
    }

    init(uncapped: Int) {
        self.lb = max(0, uncapped - 2)
        self.ub = uncapped + 2
    }

    init(_ lb: Int, _ ub: Int) {
        assert(lb <= ub)
        self.lb = lb
        self.ub = ub
    }

    init(lb: Int) {
        self.lb = lb
        self.ub = BoundedInt.infinity
    }

    var description: String {
        if isLowerBound {
            return "\(lb)+"
        }
        if isNearlyExact {
            return "\(lb)"
        }

        return "\(lb)...\(ub)"
    }

    func matches(_ value: Int) -> Bool {
        lb <= value && value <= ub
    }

    func asLowerBound() -> BoundedInt {
        if isLowerBound {
            return self
        }
        return BoundedInt(lb, BoundedInt.infinity)
    }

    func applyBounds(lb: BoundedInt, ub: BoundedInt) -> BoundedInt {
        let newMax = min(self.ub, ub.ub)
        let newMin = max(lb.lb, self.lb)
        if newMin > newMax {
            print("must have grown \(lb) <= \(self) <= \(ub)")
            if self.lb <= newMin {
                return BoundedInt(self.lb, newMin)
            } else if newMax <= self.ub {
                return BoundedInt(newMax, self.ub)
            }
            return self
        }
        return BoundedInt(newMin, newMax)
    }

    func softApplyBounds(lb: BoundedInt, ub: BoundedInt) -> BoundedInt {
        let newMax = min(self.ub, ub.ub)
        let newMin = max(lb.lb, self.lb)
        if newMin > newMax {
            return self
        }
        return BoundedInt(newMin, newMax)
    }

//    func applyBounds(_ lb: BoundedInt?) -> BoundedInt {
//        if let lowerBound = lb {
//            return applyBounds(lowerBound.value)
//        }
//        return self
//    }

    func checkIntersection(_ rhs: BoundedInt) {
        print("bad intersection \(self) \(rhs), must have grown")
    }

    func intersection(_ rhs: BoundedInt) -> BoundedInt {
        let lb = max(self.lb, rhs.lb)
        let ub = min(self.ub, rhs.ub)
        if lb > ub {
            if rhs.isLowerBound {
                let result = BoundedInt(rhs.lb, rhs.lb)
                print("1 Must have grown \(self) & \(rhs) -> \(result)")
                return result
            }
            if isLowerBound {
                let result = BoundedInt(lb, lb)
                print("2 Must have grown \(self) & \(rhs) -> \(result)")
                return result
            }
            let result = BoundedInt(lb, max(self.ub, rhs.ub))
            print("3 Must have grown \(self) & \(rhs) -> \(result)")
            return result
        }
        return BoundedInt(lb, ub)
    }

    func intersectionMaybe(_ rhs: BoundedInt) -> BoundedInt {
        let lb = max(self.lb, rhs.lb)
        let ub = min(self.ub, rhs.ub)
        if lb > ub {
            print("4 Must have grown \(self) & \(rhs) -> \(self)")
            return self
        }
        return BoundedInt(lb, ub)
    }
}

func + (lhs: BoundedInt, rhs: BoundedInt) -> BoundedInt {
    if lhs.isLowerBound || rhs.isLowerBound {
        return BoundedInt(lhs.lb + rhs.lb, BoundedInt.infinity)
    }
    return BoundedInt(lhs.lb + rhs.lb, lhs.ub + rhs.ub)
}

func minus(_ lhs: BoundedInt, _ rhs: BoundedInt) -> BoundedInt {
    lhs - rhs
}

func - (lhs: BoundedInt, rhs: BoundedInt) -> BoundedInt {
    if rhs.isLowerBound {
        return BoundedInt.unknown
    }
    if lhs.isLowerBound {
        return BoundedInt(lb: max(0, lhs.lb - rhs.ub))
    }
    return BoundedInt(max(0, lhs.lb - rhs.ub), max(0, lhs.ub - rhs.lb))
}

func / (lhs: BoundedInt, rhs: Int) -> BoundedInt {
    if lhs.isLowerBound {
        return BoundedInt(lb: lhs.lb / rhs)
    }
    return BoundedInt(lhs.lb / rhs, lhs.ub / rhs)
}

func == (lhs: BoundedInt, rhs: Int) -> Bool {
    lhs.lb <= rhs && rhs <= lhs.ub
}

func > (lhs: BoundedInt, rhs: Int) -> Bool {
    lhs.lb > rhs
}

func intersection(_ lhs: BoundedInt, _ rhs: BoundedInt) -> BoundedInt {
    lhs.intersection(rhs)
}
