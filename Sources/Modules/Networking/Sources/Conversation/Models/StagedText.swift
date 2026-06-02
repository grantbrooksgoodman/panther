//
//  StagedText.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

enum StagedText {
    // MARK: - Cases

    case appStoreDownload
    case appStoreVerify
    case beachDayCheckOut
    case beachDayTable
    case penPalsGreeting
    case vacationPlanning
    case viewOriginalGreeting
    case viewOriginalIncoming
    case viewOriginalMeantime

    // MARK: - Methods

    func text(
        for languageCode: String
    ) -> String {
        switch self {
        case .appStoreDownload:
            switch languageCode { // swiftlint:disable line_length
            case "de": "Ganz einfach! Lade sie einfach aus dem App Store herunter und gib deine Telefonnummer ein. Das war\u{2019}s!"
            case "es": "\u{00A1}Es f\u{00E1}cil! Solo tienen que descargarla de la App Store e ingresar su n\u{00FA}mero de tel\u{00E9}fono. \u{00A1}Eso es todo!"
            case "fr": "C\u{2019}est simple\u{00A0}! Il suffit de la t\u{00E9}l\u{00E9}charger sur l\u{2019}App Store et d\u{2019}entrer ton num\u{00E9}ro de t\u{00E9}l\u{00E9}phone. C\u{2019}est tout\u{00A0}!"
            case "it": "\u{00C8} facile! Basta scaricarla dall\u{2019}App Store e inserire il numero di telefono. Tutto qui!"
            case "zh": "很简单！只需从 App Store 下载并输入手机号码就行了！"
            default: "It\u{2019}s easy! Just download it from the App Store and enter your phone number. That\u{2019}s it!" // swiftlint:enable line_length
            }

        case .appStoreVerify:
            switch languageCode {
            case "de": "Nein! Einfach deine Telefonnummer best\u{00E4}tigen und du kannst loschatten!"
            case "es": "\u{00A1}No! Solo verifica tu n\u{00FA}mero de tel\u{00E9}fono y estar\u{00E1}s listo para chatear."
            case "fr": "Non\u{00A0}! V\u{00E9}rifie juste ton num\u{00E9}ro de t\u{00E9}l\u{00E9}phone et tu pourras discuter\u{00A0}!"
            case "it": "No! Basta verificare il numero di telefono e sei pronto a chattare!"
            case "zh": "不用！只需验证手机号码就可以开始聊天了！"
            default: "Nope! Just verify your phone number, and you\u{2019}ll be ready to chat!"
            }

        case .beachDayCheckOut:
            switch languageCode {
            case "de": "Schau dir die Aussicht am Strand an!"
            case "es": "\u{00A1}Mira la vista en la playa!"
            case "fr": "Regarde la vue \u{00E0} la plage !"
            case "it": "Guarda che vista al mare!"
            case "zh": "看看海滩的景色！"
            default: "Check out the view at the beach!"
            }

        case .beachDayTable:
            switch languageCode {
            case "de": "Ich besorge uns einen Tisch. Bis gleich!"
            case "es": "Voy a conseguirnos una mesa. \u{00A1}Nos vemos pronto!"
            case "fr": "Je nous trouve une table. \u{00C0} bient\u{00F4}t !"
            case "it": "Ci prendo un tavolo. A presto!"
            case "zh": "我去找张桌子。回头见！"
            default: "I\u{2019}ll get us a table. See you soon!"
            }

        case .penPalsGreeting:
            switch languageCode {
            case "de": "Hallo zusammen! Woher kommt ihr alle?"
            case "es": "\u{00A1}Hola a todos! \u{00BF}De d\u{00F3}nde son?"
            case "fr": "Salut tout le monde\u{00A0}! Vous venez d\u{2019}o\u{00F9}\u{00A0}?"
            case "it": "Ciao a tutti! Da dove venite?"
            case "zh": "大家好！你们都来自哪里？"
            default: "Hey everyone! Where are you all from?"
            }

        case .vacationPlanning:
            switch languageCode {
            case "de": "Danke f\u{00FC}r die Organisation!"
            case "es": "\u{00A1}Gracias por organizar!"
            case "fr": "Merci d'avoir organis\u{00E9} !"
            case "it": "Grazie per aver organizzato!"
            case "zh": "谢谢你组织这次活动！"
            default: "Thanks for organizing!"
            }

        case .viewOriginalGreeting:
            switch languageCode {
            case "de": "Hey, es war toll, dich neulich kennenzulernen! Ich hoffe, du hattest einen guten Flug nach Hause."
            case "es": "\u{00A1}Oye, fue genial conocerte el otro d\u{00ED}a! Espero que hayas tenido un buen vuelo a casa."
            case "fr": "Salut, c\u{2019}\u{00E9}tait super de te rencontrer l\u{2019}autre jour\u{00A0}! J\u{2019}esp\u{00E8}re que tu as fait bon vol."
            case "it": "Ehi, \u{00E8} stato bello conoscerti l\u{2019}altro giorno! Spero che tu abbia fatto un buon volo."
            case "zh": "嘿，前几天认识你真开心！希望你回去的航班一切顺利。"
            default: "Hey, it was great to meet you the other day! Hope you had a good flight home."
            }

        case .viewOriginalIncoming:
            switch languageCode {
            case "de": "Danke, ich hatte viel Spa\u{00DF}. Ich hoffe, dich bald wiederzusehen!"
            case "es": "Gracias, me divert\u{00ED} mucho. \u{00A1}Espero volver a verte pronto!"
            case "fr": "Merci, je me suis bien amus\u{00E9}. J\u{2019}esp\u{00E8}re te revoir bient\u{00F4}t\u{00A0}!"
            case "it": "Grazie, mi sono divertito molto. Spero di rivederti presto!"
            case "zh": "谢谢，我玩得很开心。希望很快能再见到你！"
            default: "Thanks, I had a lot of fun. I hope to see you again soon!"
            }

        case .viewOriginalMeantime:
            switch languageCode {
            case "de": "Ebenso \u{2013} und in der Zwischenzeit k\u{00F6}nnen wir auf Hello chatten! \u{1F603}"
            case "es": "Igualmente \u{2013} y mientras tanto, \u{00A1}podemos chatear en Hello! \u{1F603}"
            case "fr": "De m\u{00EA}me \u{2013} et en attendant, on peut discuter sur Hello\u{00A0}! \u{1F603}"
            case "it": "Anche io \u{2013} e nel frattempo possiamo chattare su Hello! \u{1F603}"
            case "zh": "我也是 \u{2013} 在此期间我们可以在 Hello 上聊天！\u{1F603}"
            default: "Likewise \u{2013} and in the meantime, we can chat on Hello! \u{1F603}"
            }
        }
    }
}
