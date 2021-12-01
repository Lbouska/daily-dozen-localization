//
//  StringzProcessor.swift
//  AppLocalizerLib
//
//

import Foundation

// File format as generated by xliff import
// 1. no header line(s)
// 2. always has a note comment line
// 3. keys are in alphabetical order
// 4. empty string "" source & target values have xml representation: `<source/><target/>` 
// 5. always a blank line between each note/key-value pair
//
// ```
// /* <note goes inside comment syntax> */
// "keyIsQuoted"="valueIsQuoted";
// <blank line>
// /* (No Comment) */
// "key"="value";
// 
// ```

struct StringzProcessor: TsvProtocol {

    var tsvRowList = TsvRowList()
    
    init() {}
    
    init(tsvRowList: TsvRowList) {
        self.tsvRowList = tsvRowList
    }
    
    mutating func parse(url: URL) {
        var key_apple = ""
        var lang_value = ""
        var base_note = ""
        var lang_note = ""
        
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("::ERROR:PARSE::READ::\n:: \(url.path)")
            return
        }
        
        let lines = content.components(separatedBy: "\n")
        for var l in lines {
            l = l.trimmingCharacters(in: CharacterSet.whitespaces)
            if l.isEmpty { continue }
            
            if l.hasPrefix("/*") && l.hasSuffix("*/") {
                base_note = l
                    .dropFirst(2) // /*
                    .dropLast(2)  // */
                    .trimmingCharacters(in: CharacterSet.whitespaces)
                // :NYI: no `lang_note` separated from comment
                continue
            } 
            
            if l.hasPrefix("\"") && l.hasSuffix("\";") {
                let parts = l.components(separatedBy: "\" = \"")
                
                guard parts.count == 2 else {
                    print("::NYI:PARSE::PARTS::\n:: \(url.path)\n::\(l)")
                    
                    // clear values
                    key_apple = ""
                    lang_value = ""
                    base_note = ""
                    lang_note = ""
                    continue
                }
                
                key_apple = String(parts[0].dropFirst(1)) // double quote "
                lang_value = String(parts[1].dropLast(2)) // ";
                let row = TsvRow(
                    key_android: "", 
                    key_apple: key_apple, 
                    base_value: "", 
                    lang_value: lang_value, 
                    base_note: base_note,
                    lang_note: lang_note)
                tsvRowList.append(row)
                
                // clear values
                key_apple = ""
                lang_value = ""
                base_note = ""
                lang_note = ""
                
                continue
            }
            
            print("::NYI:PARSE::\n:: \(url.path)\n::\(l)")
        }
        
        // Normalize key_apple, key_droid
        let tsvSheet = TsvSheet(tsvRowList: tsvRowList)
        tsvRowList = tsvSheet.tsvRowList
    }
    
    // MARK: - Operations

    // MARK: - Output

    enum SplitFile: String {
        case infoPlist = "InfoPlist"
        case localizable = "Localizable"
        
        var name: String {
            return self.rawValue
        }
    }
    
    let infoPlistKeys = ["CFBundleDisplayName", "CFBundleName", "NSHealthShareUsageDescription", "NSHealthUpdateUsageDescription"]

    //func toString() -> String {
    //    var s = ""
    //    let contentDict = toStringSplitByFile()
    //    
    //    for (key, value) in contentDict {
    //        s.append("##########################\n")
    //        s.append("##### \(key)\n")
    //        s.append("##########################\n")
    //        s.append("value")            
    //    }
    //    return s
    //}
    
    func toStringSplitByFile(langCode: String) -> [SplitFile: String] {
        var sInfoPlist = """
        /* DailyDozen InfoPlist.strings (\(langCode)) */
        /* Copyright © 2021 Nutritionfacts.org. All rights reserved. */
        \n
        """
        var sLocalizable = """
        /* DailyDozen Localizable.strings (\(langCode)) */
        /* Copyright © 2021 Nutritionfacts.org. All rights reserved. */
        \n
        """
        
        var applekeyEmptyList = TsvRowList()
        var langvalueMissingList = TsvRowList()
        var langvalueUntranslatedList = TsvRowList()
        var randomidList = TsvRowList()
        
        for row in self.tsvRowList.sorted().data {
            let comment = row.base_note
            let key = row.key_apple
            let value = row.lang_value
                .replacingOccurrences(of: "\"", with: "\\\"")
            
            // Case: key_apple
            if row.key_apple.isEmpty {
                applekeyEmptyList.append(row)
                continue
            }

            // Case: not translated value 
            if row.lang_value.isEmpty {
                langvalueMissingList.append(row)
            }

            // Case: autogenrated Apple Random Storyboard ID
            if row.base_value == row.lang_value {
                langvalueUntranslatedList.append(row)
            }

            // Case: autogenrated Apple Random Storyboard ID
            if row.key_apple.isRandomKey {
                randomidList.append(row)
            }
            
            if isJsonOnly(key) {
                // do not append
            } else if infoPlistKeys.contains(key) {
                sInfoPlist.append("/* \(comment) */\n")
                sInfoPlist.append("\"\(key)\" = \"\(value)\";\n")
                sInfoPlist.append("\n")
            } else {
                sLocalizable.append("/* \(comment) */\n")
                sLocalizable.append("\"\(key)\" = \"\(value)\";\n")
                sLocalizable.append("\n")                
            }
            
        }

        sInfoPlist.append("/* file end */\n")
        sLocalizable.append("/* file end */\n")
        
        print("#######################################")
        print("### key_apple: empty (Android Only) ###")
        print("#######################################")
        print("### (not in *.stringz)")
        for row in applekeyEmptyList.data {
            print("\(row.key_android)\t\(row.base_value)")
        }
        
        print("###########################")
        print("### lang_value: missing ###")
        print("###########################")
        print("### (in *.stringz)")
        for row in langvalueMissingList.data {
            print("\(row.key_apple)\t\(row.base_value)")
        }

        print("################################")
        print("### lang_value: untranslated ###")
        print("################################")
        print("### (in *.stringz)")
        for row in langvalueUntranslatedList.data {
            print("\(row.key_apple)\t\(row.base_value)")
        }

        print("######################################")
        print("### key_apple: storyboard randomid ###")
        print("######################################")
        print("### (in *.stringz)")
        for row in randomidList.data {
            print("\(row.key_apple)\t\(row.base_value)")
        }        
        
        return [.infoPlist: sInfoPlist, .localizable: sLocalizable]
    }
    
    /// Is string localized in *.json files and not present in the *.strings files?
    /// Does not filter out URL topic strings. 
    /// `heading` strings are included in both *.strings and *.json.  
    private func isJsonOnly(_ s: String) -> Bool {
        if s.hasPrefix("doze") {
            if s.contains(".Serving.") || s.contains(".Variety.") {
                return true
            }
        }
        if s.hasPrefix("tweak") {
            if s.contains(".short") || s.contains(".text") {
                return true
            }
        }
        return false
    }
}
