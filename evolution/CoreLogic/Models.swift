//
//  Models.swift
//  evolution
//
//  Created by Purav Manot on 21/11/20.
//

import Foundation
import SwiftUI

//Species
struct Species: Identifiable, Hashable {
    let id = UUID()
    var genome: [SpeciesDNA]
    var identifier: String
    var color: Color
    var foodEnergy: [Food]
    var speed: Int // scale of 1 - 10
    var size: Int = 1 // scale of 1 - 5
    var cost: Double {
        Double(speed*size).mappedValue(inputRange: 1..<50, outputRange: 1..<2)
    }
    var lifespan: Double
    var movementCounter: Int
    var foodDetected: Bool = false
    let maxLifespan: Double
    var disabled: Bool // to be toggled at death, stops all calculations and movement
    var coordinates: Point // position of self
    var bounds: Bounds // boundaries to stop self from going out of given frame
    // var infected: Bool = false // coming soon
    var dir = CGFloat.random(in: 0..<2*(.pi)) //direction in radians
    var sightRadius: Double
    init(name: String, speed: Int, lifespan: Double, sight: Double = 5, infected: Bool = false, coordinates: Point = Point(x: 200, y: 300), bounds: Bounds = SpeciesEnvironment().bounds, color: Color = .green) {
        self.identifier = name
        self.speed = speed
        self.lifespan = lifespan
        self.maxLifespan = lifespan
        // self.infected = infected
        self.coordinates = coordinates
        self.bounds = bounds
        self.sightRadius = sight
        self.foodEnergy = []
        self.color = color
        self.disabled = false
        self.movementCounter = Int(10 - speed)
        self.foodDetected = false
        genome = []
        genome.append(SpeciesDNA(name, speed: speed, sight: sight, size: self.size, color: self.color))
    }
    
    init(_ base: SpeciesDNA, lifespan: Double, bounds: Bounds = SpeciesEnvironment().bounds) {
        identifier = base.identifier
        speed = base.speed
        color = base.color
        self.bounds = bounds
        self.lifespan = lifespan
        self.sightRadius = base.sight
        self.coordinates = randomPoint(bounds: bounds)
        self.foodEnergy = []
        self.maxLifespan = lifespan
        self.disabled = false
        self.movementCounter = Int(10 - speed)
        self.foodDetected = false
        genome = []
        genome.append(base)
    }
    
    mutating func updatePos() { // updates the xy position of a cell (called at fixed intervals of time)
        if !disabled {
            if movementCounter <= 0 {
                movementCounter = Int(10 - speed)
            }
            if movementCounter == Int(10 - speed) {
                coordinates.x += cos(dir)*10 //increase the x position
                coordinates.y -= sin(dir)*10 //increase the y position
                if !foodDetected {
                    updateDir()
                }
                lifespan -= cost // 1 step
                avoidBounds()
            }
            movementCounter -= 1
            if foodEnergy.count >= 1 {
                lifespan = maxLifespan
            }
        }
        disabled = lifespan <= 0
    }
    
    mutating func dayReset(){
        if foodEnergy.count >= 1 {
            lifespan = maxLifespan
        }
        foodEnergy = []
    }
    
    mutating func updateDir(_ rStart: CGFloat = -0.02, _ rEnd: CGFloat = 0.02) { // changes the direction of a cell slightly from its given direction
        dir += CGFloat.random(in: rStart..<rEnd)
        if dir > 2*(.pi) || dir < 0 { // make sure direction stays within the range of a full rotation (2pi)
            dir = CGFloat.random(in: 0..<2*(.pi))
        }
    }
    
    func onDeath(_ x: () -> ()) { // execute closure when cell dies
        if disabled {
            x()
        }
    }
    
    func remove(from arr: inout [Species]) {
        arr.removeAll(where: { $0.id == self.id })
    }
    
    mutating func avoidBounds() { // bounds collision function to prevent cells from going out of bound
        if coordinates.x < bounds.left || coordinates.x > bounds.right || coordinates.y > bounds.down || coordinates.y < bounds.up {
            coordinates.x.cap(bounds.left..<bounds.right)
            coordinates.y.cap(bounds.up..<bounds.down)
            dir = CGFloat.random(in: 0..<2*(.pi))
        }
    }
    
    mutating func forage(_ food: [Food]) {
        if self.detectedFoodID == nil {
            for f in 0..<food.count {
                withinLimit(f, food.count) { // make sure f is a valid index
                    if self.coordinates.inRange(of: food[f].position, radiusSquared: self.sightRadius*2) {
                        let value = atan(abs(food[f].position.y - self.coordinates.y)/abs(self.coordinates.x - food[f].position.x))
                        if (self.coordinates.x - food[f].position.x) >= 0 && (food[f].position.y - self.coordinates.y) >= 0 { // 1st quadrant works
                            dir = (.pi) - value
                            print("A")
                        }
                        else if (self.coordinates.x - food[f].position.x) <= 0 && (food[f].position.y - self.coordinates.y) <= 0 { // 3rd quadrant doesn't work
                            dir = 2*(.pi) - value
                            print("B")
                        }
                        else if (self.coordinates.x - food[f].position.x) >= 0 && (food[f].position.y - self.coordinates.y) <= 0 { // 4th quadrant works
                            dir = value + (.pi)
                            print("C")
                        }
                        else if (self.coordinates.x - food[f].position.x) <= 0 && (food[f].position.y - self.coordinates.y) >= 0 { // 2nd quadrant works
                            dir = value
                            print("D")
                        }
                        dir = 2*(.pi) - dir
                        self.detectedFoodID = food[f].id
                    }
                }
            }
        }
    }

    mutating func eatFood(_ food: inout [Food]) {
        if detectedFoodID == nil {
            forage(food)
        } else {
            if food.first(where: {$0.id == detectedFoodID!}) != nil {
                if abs(food.first(where: {$0.id == detectedFoodID!})!.position.x - self.coordinates.x) <= 5 {
                    if self.detectedFoodID != nil {
                        let m = food.first(where: {$0.id == detectedFoodID!})!
                        food.removeAll(where: {$0.id == detectedFoodID!})
                        foodEnergy.append(m)
                    }
                    self.detectedFoodID = nil
                }
            }
        }
    }
    
    func replicate(_ speciesArray: inout Array<Species>){
        var offspring = Species(self.genome, lifespan: self.maxLifespan, bounds: self.bounds)
        offspring.coordinates = self.coordinates
        speciesArray.append(offspring)
    }
}

struct SpeciesDNA: Hashable {
    var identifier: String
    var speed: Int
    var sight: Double
    var size: Int
    var color: Color
    init(_ identifier: String, speed: Int, sight: Double, size: Int, color: Color){
        self.identifier = identifier
        self.speed = speed
        self.sight = sight
        self.size = size
        self.color = color
    }
}

struct Food: Identifiable, Hashable {
    var id = UUID()
    var energy: Double // foods with higher energy allow cells to survive longer
    var color: Color
    var position: Point
    init(energy: Double, color: Color, position: Point) {
        self.energy = energy
        self.color = color
        self.position = position
    }
}

struct Bounds: Hashable { // used to define the boundaries of a frame
    var left: CGFloat
    var right: CGFloat
    var up: CGFloat
    var down: CGFloat
    init(frame: CGSize, position: CGPoint) {
        self.left = position.x - frame.width/2
        self.right = position.x + frame.width/2
        self.up = position.y - frame.height/2
        self.down = position.y + frame.height/2
    }
    init(left: CGFloat, right: CGFloat, up: CGFloat, down: CGFloat) {
        self.left = left
        self.right = right
        self.up = up
        self.down = down
    }
}

struct Point: Hashable, Strideable { // Custom CGPoint struct that conforms to Hashable and Strideable
    var x: CGFloat
    var y: CGFloat
    func distanceSquared(to other: Point) -> Double { // calculates the distance between two points
        let delta_x2 = Double(self.x - other.x).magnitudeSquared
        let delta_y2 = Double(self.y - other.y).magnitudeSquared
        return (delta_x2 + delta_y2)
    }
    
    func distance(to other: Point) -> CGFloat { // calculates the distance between two points
        let delta_x2 = Double(self.x - other.x).magnitudeSquared
        let delta_y2 = Double(self.y - other.y).magnitudeSquared
        return CGFloat((delta_x2 + delta_y2)).squareRoot()
    }
    
    func advanced(by n: CGFloat) -> Point {
        Point(x: self.x + n, y: self.y + n)
    }
    
    func line(_ a: Point, _ b: Point) -> (m: Double, c: Double) { // returns the gradient and y intercept of a line made by two points
        let m = Double((a.y - b.y) / (a.x - b.x))
        return (m: Double((a.y - b.y) / (a.x - b.x)), c: (Double(y) - m*Double(x)))
    }
    
    func liesOn(_ a: Point, _ b: Point) -> Bool { // returns true if point lies on a line (ie. all 3 points are collinear)
        let l = line(a, b)
        return Double(self.y) == Double(self.x)*l.m + l.c
    }
    
    func inRange(of point: Point, radiusSquared: Double = 25) -> Bool { // used to detect a collision / touch between two objects
        if !(Double(abs(self.y - point.y)) >= radiusSquared) && !(Double(abs(self.y - point.y)) >= radiusSquared) {
            return self.distanceSquared(to: point) <= radiusSquared
        }
        return false
    }
}

func delay(_ time: Double, _ x: @escaping () -> ()){
    DispatchQueue.main.asyncAfter(deadline: .now() + time, execute: x)
}
