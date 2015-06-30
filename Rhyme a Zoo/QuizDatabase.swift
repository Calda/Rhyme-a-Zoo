//
//  QuizDatabase.swift
//  Rhyme a Zoo
//
//  Created by Cal on 6/30/15.
//  Copyright (c) 2015 Cal Stephens. All rights reserved.
//

import Foundation
import SQLite

///Global database. QuizDatabase -> Quiz -> Question -> Option
let RZQuizDatabase = QuizDatabase()

///SQLite.swift wrapper for the legacy databace from the PC version of Rhyme a Zoo.
private let sql = Database(NSBundle.mainBundle().pathForResource("LegacyDB", ofType: "db")!, readonly: true)
//QUIZ table
private let Quizes = sql["QUIZ"]
private let QuizNumber = Expression<Int>("QuizNo")
private let QuizName = Expression<String>("Name")
private let QuizLevel = Expression<Int>("Level")
private let QuizRhymeText = Expression<String>("RhymeText")
private let QuizDisplayOrder = Expression<Int>("D_ORDER")
//AUDIOTIME table
private let AudioTime = sql["AUDIOTIME"]
let AudioWord = Expression<Int>("Word")
let AudioStartTime = Expression<Int>("StartTime")
//QUESTION table
private let Questions = sql["Question"]
private let QuestionNumber = Expression<Int>("QuestionNo")
private let QuestionAnswer = Expression<String>("Answer")
private let QuestionCategory = Expression<String>("Category")
private let QuestionText = Expression<String>("QuestionText")
//WORDBANK table
private let WordBank = sql["WORDBANK"]
let WordText = Expression<String>("Word")
let WordCategory = Expression<Int>("Category")

///Top level database structure. Globally available at RZQuizDatabase. Contains many Quizes.
///Quiz Database -> Quiz -> Question -> Option
class QuizDatabase {
    
    private var quizNumberMap: [Int] = []
    var count: Int {
        get {
            return quizNumberMap.count
        }
    }
    var levelCount: Int = 24 //24 levels. This is just a fact.
    
    init() {
        for level in 1...levelCount {
            var displayOrderArray: [Int?] = [nil, nil, nil, nil, nil]
            for quiz in Quizes.filter(QuizLevel == level) {
                let quizNumber = quiz[QuizNumber]
                let quizDisplayOrder = quiz[QuizDisplayOrder]
                displayOrderArray[quizDisplayOrder - 1] = quizNumber
            }
            
            for quiz in displayOrderArray {
                if let quiz = quiz {
                    quizNumberMap.append(quiz)
                }
            }
        }
        
        
        for quiz in Quizes.select(QuizNumber) {
            quizNumberMap.append(quiz[QuizNumber])
        }
    }
    
    func getQuiz(index: Int) -> Quiz {
        let number = quizNumberMap[index]
        return Quiz(number)
    }
    
    func quizesForLevel(level: Int) -> [Quiz!] {
        var displayOrderArray: [Quiz!] = [nil, nil, nil, nil, nil]
        for quiz in Quizes.filter(QuizLevel == level) {
            let quizNumber = quiz[QuizNumber]
            let quizDisplayOrder = quiz[QuizDisplayOrder]
            displayOrderArray[quizDisplayOrder - 1] = Quiz(quizNumber)
        }
        return displayOrderArray.filter{ $0 != nil }
    }
    
}

///Avaliable though RZQuizDatabase. Contains 4 Questions.
struct Quiz : Printable {
    
    let quiz: Query
    ///"QUIZ" table
    let number: Int
    let name: String
    let level: Int
    var questions: [Question] {
        get {
            var array: [Question] = []
            for question in Questions.filter(QuizNumber == number) {
                let questionNumber = question[QuestionNumber]
                array.append(Question(questionNumber))
            }
            return array
        }
    }
    var description: String {
        get{
            return "(Quiz \(number))[\(name)]"
        }
    }
    
    init(_ number: Int) {
        self.number = number
        
        quiz = Quizes.filter(QuizNumber == self.number)
        let data = quiz.select(QuizName, QuizLevel).first!
        self.name = data[QuizName]
        self.level = data[QuizLevel]
    }
    
    var rhymeText: String {
        get{
            let data = quiz.select(QuizRhymeText).first!
            return data[QuizRhymeText]
        }
    }
    
    var wordStartTimes: [Int] {
        get {
            let data = AudioTime.filter(QuizNumber == self.number).select(AudioStartTime)
            var array: [Int] = []
            for word in data {
                array.append(word[AudioStartTime])
            }
            return array
        }
    }
    

}

///Owned by a Quiz. Contains 4 Options.
struct Question: Printable {
    
    let question: Query
    //"QUESTION" table
    let quizNumber: Int
    let number: Int
    let answer: String
    let category: Int
    let text: String
    var options: [Option] {
        get {
            var array: [Option] = []
            for option in WordBank.filter(WordCategory == category) {
                let wordText = option[WordText]
                array.append(Option(word: wordText))
            }
            return array.shuffled()
        }
    }
    var description: String {
        get{
            return "(Question \(number))[\(text)]"
        }
    }

    init(_ number: Int) {
        self.number = number
        
        question = Questions.filter(QuestionNumber == self.number)
        let data = question.select(QuizNumber, QuestionAnswer, QuestionCategory, QuestionText).first!
        quizNumber = data[QuizNumber]
        answer = data[QuestionAnswer]
        category = data[QuestionCategory].toInt()!
        text = data[QuestionText]
    }
    
}

///Owned by a Question. The smallest element of the database.
struct Option: Printable {
    
    let word: String
    var description: String {
        get{
            return word
        }
    }
    
    init(word: String) {
        self.word = word
    }
    
    //TODO: implement getters for image and audio
    
}


extension Array {
    func shuffled() -> [T] {
        var list = self
        for i in 0..<(list.count - 1) {
            let j = Int(arc4random_uniform(UInt32(list.count - i))) + i
            swap(&list[i], &list[j])
        }
        return list
    }
}