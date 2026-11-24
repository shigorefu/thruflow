import Foundation

// Entirely fictional screenshot fixtures. These simulate user-authored data and
// deliberately do not add product UI keys to the String Catalog.
// Marked literals are the five-language fixture values persisted into the isolated
// screenshot store, matching the existing localisation-audit persisted-value rule.
struct ScreenshotCopy {
    private let language: ScreenshotLanguage

    /// Fixed order: reports, language practice, photography basics, daily sketching.
    var projectNames: [String] {
        switch language {
        case .ja: ["レポート作成", "語学練習", "写真の基礎", "毎日のスケッチ"] // localisation-audit: persisted-value
        case .en: ["Reports", "Language Practice", "Photography Basics", "Daily Sketching"] // localisation-audit: persisted-value
        case .ru: ["Отчёты", "Языковая практика", "Основы фотографии", "Ежедневные наброски"] // localisation-audit: persisted-value
        case .zhHans: ["报告撰写", "语言练习", "摄影基础", "每日速写"] // localisation-audit: persisted-value
        case .zhHant: ["報告撰寫", "語言練習", "攝影基礎", "每日速寫"] // localisation-audit: persisted-value
        }
    }

    let workDirection: String
    let studyDirection: String
    let readingDirection: String
    let healthDirection: String
    let personalDirection: String
    let otherDirection: String

    let featuredTitle: String
    let featuredNotes: String
    let featuredHashtags: [String]
    let emailTitle: String
    let emailHashtags: [String]
    let planTitle: String
    let planHashtags: [String]
    let readingTitle: String
    let readingNotes: String
    let readingHashtags: [String]
    let studyTitle: String
    let studyNotes: String
    let studyHashtags: [String]
    let runTitle: String
    let journalTitle: String
    let tidyTitle: String

    let readingMemo: String
    let reportOutlineMemo: String
    let reportFinishMemo: String
    let studyMemo: String
    let runMemo: String
    let templates: ScreenshotTaskTemplates

    init(language: ScreenshotLanguage) {
        self.language = language
        switch language {
        case .ja:
            workDirection = "仕事" // localisation-audit: persisted-value
            studyDirection = "勉強" // localisation-audit: persisted-value
            readingDirection = "読書" // localisation-audit: persisted-value
            healthDirection = "健康" // localisation-audit: persisted-value
            personalDirection = "自分の時間" // localisation-audit: persisted-value
            otherDirection = "その他" // localisation-audit: persisted-value

            featuredTitle = "報告書を仕上げる" // localisation-audit: persisted-value
            featuredNotes = "要点と数字を見直す" // localisation-audit: persisted-value
            featuredHashtags = ["仕事", "今週"] // localisation-audit: persisted-value
            emailTitle = "メールに返信する" // localisation-audit: persisted-value
            emailHashtags = ["仕事"] // localisation-audit: persisted-value
            planTitle = "明日の予定を確認する" // localisation-audit: persisted-value
            planHashtags = ["予定"] // localisation-audit: persisted-value
            readingTitle = "本を読む" // localisation-audit: persisted-value
            readingNotes = "第8章から" // localisation-audit: persisted-value
            readingHashtags = ["読書"] // localisation-audit: persisted-value
            studyTitle = "単語と例文を復習する" // localisation-audit: persisted-value
            studyNotes = "新しい単語を使って短い文を書く" // localisation-audit: persisted-value
            studyHashtags = ["勉強"] // localisation-audit: persisted-value
            runTitle = "走る" // localisation-audit: persisted-value
            journalTitle = "日記を書く" // localisation-audit: persisted-value
            tidyTitle = "部屋を片づける" // localisation-audit: persisted-value

            readingMemo = "第8章まで読んだ" // localisation-audit: persisted-value
            reportOutlineMemo = "要点を書き出した" // localisation-audit: persisted-value
            reportFinishMemo = "文章と数字を整えた" // localisation-audit: persisted-value
            studyMemo = "単語を復習して例文を書いた" // localisation-audit: persisted-value
            runMemo = "ゆっくり5km走った" // localisation-audit: persisted-value
            templates = ScreenshotTaskTemplates(
                work: [
                    "報告書をまとめる", // localisation-audit: persisted-value
                    "メールに返信する", // localisation-audit: persisted-value
                    "資料を確認する", // localisation-audit: persisted-value
                    "会議の準備をする", // localisation-audit: persisted-value
                    "予定を整理する", // localisation-audit: persisted-value
                ],
                study: [
                    "単語を復習する", // localisation-audit: persisted-value
                    "短い会話を聞く", // localisation-audit: persisted-value
                    "文法の練習をする", // localisation-audit: persisted-value
                    "ノートをまとめる", // localisation-audit: persisted-value
                    "短い文章を読む", // localisation-audit: persisted-value
                ],
                reading: [
                    "本を25ページ読む", // localisation-audit: persisted-value
                    "小説を読む", // localisation-audit: persisted-value
                    "読書メモを書く", // localisation-audit: persisted-value
                    "小説を1章読む", // localisation-audit: persisted-value
                ],
                health: [
                    "朝走る", // localisation-audit: persisted-value
                    "ストレッチする", // localisation-audit: persisted-value
                    "散歩する", // localisation-audit: persisted-value
                    "筋トレする", // localisation-audit: persisted-value
                ],
                personal: [
                    "部屋を片づける", // localisation-audit: persisted-value
                    "買い物に行く", // localisation-audit: persisted-value
                    "家族に電話する", // localisation-audit: persisted-value
                    "夕食を作る", // localisation-audit: persisted-value
                    "日記を書く", // localisation-audit: persisted-value
                ],
                other: [
                    "支払いを済ませる", // localisation-audit: persisted-value
                    "ごみを出す", // localisation-audit: persisted-value
                    "写真を整理する", // localisation-audit: persisted-value
                ],
                memos: [
                    "予定したところまで終えた", // localisation-audit: persisted-value
                    "要点をまとめた", // localisation-audit: persisted-value
                    "次にやることを決めた", // localisation-audit: persisted-value
                    "集中して進められた", // localisation-audit: persisted-value
                    "気になるところを見直した", // localisation-audit: persisted-value
                    "ひと区切りついた", // localisation-audit: persisted-value
                ],
                focusHashtag: "集中" // localisation-audit: persisted-value
            )

        case .en:
            workDirection = "Work" // localisation-audit: persisted-value
            studyDirection = "Study" // localisation-audit: persisted-value
            readingDirection = "Reading" // localisation-audit: persisted-value
            healthDirection = "Health" // localisation-audit: persisted-value
            personalDirection = "Personal" // localisation-audit: persisted-value
            otherDirection = "Other" // localisation-audit: persisted-value

            featuredTitle = "Finish the report" // localisation-audit: persisted-value
            featuredNotes = "Review the key points and figures" // localisation-audit: persisted-value
            featuredHashtags = ["Work", "ThisWeek"] // localisation-audit: persisted-value
            emailTitle = "Reply to emails" // localisation-audit: persisted-value
            emailHashtags = ["Work"] // localisation-audit: persisted-value
            planTitle = "Plan tomorrow" // localisation-audit: persisted-value
            planHashtags = ["Planning"] // localisation-audit: persisted-value
            readingTitle = "Read a book" // localisation-audit: persisted-value
            readingNotes = "Start with chapter 8" // localisation-audit: persisted-value
            readingHashtags = ["Reading"] // localisation-audit: persisted-value
            studyTitle = "Review words and examples" // localisation-audit: persisted-value
            studyNotes = "Write short sentences using new words" // localisation-audit: persisted-value
            studyHashtags = ["Study"] // localisation-audit: persisted-value
            runTitle = "Go for a run" // localisation-audit: persisted-value
            journalTitle = "Write in my journal" // localisation-audit: persisted-value
            tidyTitle = "Tidy the room" // localisation-audit: persisted-value

            readingMemo = "Finished chapter 8" // localisation-audit: persisted-value
            reportOutlineMemo = "Outlined the key points" // localisation-audit: persisted-value
            reportFinishMemo = "Polished the text and figures" // localisation-audit: persisted-value
            studyMemo = "Reviewed words and wrote example sentences" // localisation-audit: persisted-value
            runMemo = "Ran an easy 5 km" // localisation-audit: persisted-value
            templates = ScreenshotTaskTemplates(
                work: [
                    "Prepare the report", // localisation-audit: persisted-value
                    "Reply to emails", // localisation-audit: persisted-value
                    "Review the documents", // localisation-audit: persisted-value
                    "Prepare for the meeting", // localisation-audit: persisted-value
                    "Plan the week", // localisation-audit: persisted-value
                ],
                study: [
                    "Review vocabulary", // localisation-audit: persisted-value
                    "Listen to a short conversation", // localisation-audit: persisted-value
                    "Practice grammar", // localisation-audit: persisted-value
                    "Organize my notes", // localisation-audit: persisted-value
                    "Read a short text", // localisation-audit: persisted-value
                ],
                reading: [
                    "Read 25 pages", // localisation-audit: persisted-value
                    "Read a novel", // localisation-audit: persisted-value
                    "Write reading notes", // localisation-audit: persisted-value
                    "Read one chapter", // localisation-audit: persisted-value
                ],
                health: [
                    "Morning run", // localisation-audit: persisted-value
                    "Stretch", // localisation-audit: persisted-value
                    "Take a walk", // localisation-audit: persisted-value
                    "Strength training", // localisation-audit: persisted-value
                ],
                personal: [
                    "Tidy the room", // localisation-audit: persisted-value
                    "Buy groceries", // localisation-audit: persisted-value
                    "Call family", // localisation-audit: persisted-value
                    "Make dinner", // localisation-audit: persisted-value
                    "Write in my journal", // localisation-audit: persisted-value
                ],
                other: [
                    "Pay the bills", // localisation-audit: persisted-value
                    "Take out the trash", // localisation-audit: persisted-value
                    "Organize photos", // localisation-audit: persisted-value
                ],
                memos: [
                    "Finished what I planned", // localisation-audit: persisted-value
                    "Summarized the key points", // localisation-audit: persisted-value
                    "Decided what to do next", // localisation-audit: persisted-value
                    "Made steady progress", // localisation-audit: persisted-value
                    "Reviewed the tricky parts", // localisation-audit: persisted-value
                    "Reached a good stopping point", // localisation-audit: persisted-value
                ],
                focusHashtag: "Focus" // localisation-audit: persisted-value
            )

        case .ru:
            workDirection = "Работа" // localisation-audit: persisted-value
            studyDirection = "Учёба" // localisation-audit: persisted-value
            readingDirection = "Чтение" // localisation-audit: persisted-value
            healthDirection = "Здоровье" // localisation-audit: persisted-value
            personalDirection = "Личное" // localisation-audit: persisted-value
            otherDirection = "Другое" // localisation-audit: persisted-value

            featuredTitle = "Подготовить отчёт" // localisation-audit: persisted-value
            featuredNotes = "Проверить выводы и цифры" // localisation-audit: persisted-value
            featuredHashtags = ["Работа", "Неделя"] // localisation-audit: persisted-value
            emailTitle = "Ответить на письма" // localisation-audit: persisted-value
            emailHashtags = ["Работа"] // localisation-audit: persisted-value
            planTitle = "Составить план на завтра" // localisation-audit: persisted-value
            planHashtags = ["Планы"] // localisation-audit: persisted-value
            readingTitle = "Почитать книгу" // localisation-audit: persisted-value
            readingNotes = "Начать с восьмой главы" // localisation-audit: persisted-value
            readingHashtags = ["Чтение"] // localisation-audit: persisted-value
            studyTitle = "Повторить слова и примеры" // localisation-audit: persisted-value
            studyNotes = "Составить предложения с новыми словами" // localisation-audit: persisted-value
            studyHashtags = ["Учёба"] // localisation-audit: persisted-value
            runTitle = "Пробежка" // localisation-audit: persisted-value
            journalTitle = "Записать итоги дня" // localisation-audit: persisted-value
            tidyTitle = "Убраться" // localisation-audit: persisted-value

            readingMemo = "Восьмая глава прочитана" // localisation-audit: persisted-value
            reportOutlineMemo = "Основные тезисы собраны" // localisation-audit: persisted-value
            reportFinishMemo = "Текст и цифры проверены" // localisation-audit: persisted-value
            studyMemo = "Слова повторены, примеры записаны" // localisation-audit: persisted-value
            runMemo = "Лёгкая пробежка на 5 км" // localisation-audit: persisted-value
            templates = ScreenshotTaskTemplates(
                work: [
                    "Подготовить отчёт", // localisation-audit: persisted-value
                    "Ответить на письма", // localisation-audit: persisted-value
                    "Проверить документы", // localisation-audit: persisted-value
                    "Подготовиться к встрече", // localisation-audit: persisted-value
                    "Составить план на неделю", // localisation-audit: persisted-value
                ],
                study: [
                    "Повторить слова", // localisation-audit: persisted-value
                    "Послушать короткий диалог", // localisation-audit: persisted-value
                    "Повторить грамматику", // localisation-audit: persisted-value
                    "Разобрать конспект", // localisation-audit: persisted-value
                    "Прочитать короткий текст", // localisation-audit: persisted-value
                ],
                reading: [
                    "Прочитать 25 страниц", // localisation-audit: persisted-value
                    "Почитать роман", // localisation-audit: persisted-value
                    "Записать мысли о книге", // localisation-audit: persisted-value
                    "Прочитать одну главу", // localisation-audit: persisted-value
                ],
                health: [
                    "Утренняя пробежка", // localisation-audit: persisted-value
                    "Растяжка", // localisation-audit: persisted-value
                    "Прогулка", // localisation-audit: persisted-value
                    "Тренировка", // localisation-audit: persisted-value
                ],
                personal: [
                    "Убраться", // localisation-audit: persisted-value
                    "Купить продукты", // localisation-audit: persisted-value
                    "Позвонить родным", // localisation-audit: persisted-value
                    "Приготовить ужин", // localisation-audit: persisted-value
                    "Записать итоги дня", // localisation-audit: persisted-value
                ],
                other: [
                    "Оплатить счета", // localisation-audit: persisted-value
                    "Вынести мусор", // localisation-audit: persisted-value
                    "Разобрать фотографии", // localisation-audit: persisted-value
                ],
                memos: [
                    "Всё запланированное выполнено", // localisation-audit: persisted-value
                    "Основные мысли записаны", // localisation-audit: persisted-value
                    "Следующий шаг определён", // localisation-audit: persisted-value
                    "Удалось хорошо продвинуться", // localisation-audit: persisted-value
                    "Сложные моменты разобраны", // localisation-audit: persisted-value
                    "Удобный момент для перерыва", // localisation-audit: persisted-value
                ],
                focusHashtag: "Фокус" // localisation-audit: persisted-value
            )

        case .zhHans:
            workDirection = "工作" // localisation-audit: persisted-value
            studyDirection = "学习" // localisation-audit: persisted-value
            readingDirection = "阅读" // localisation-audit: persisted-value
            healthDirection = "健康" // localisation-audit: persisted-value
            personalDirection = "个人生活" // localisation-audit: persisted-value
            otherDirection = "其他" // localisation-audit: persisted-value
            featuredTitle = "完成报告" // localisation-audit: persisted-value
            featuredNotes = "核对要点和数据" // localisation-audit: persisted-value
            featuredHashtags = ["工作", "本周"] // localisation-audit: persisted-value
            emailTitle = "回复邮件" // localisation-audit: persisted-value
            emailHashtags = ["工作"] // localisation-audit: persisted-value
            planTitle = "安排明天的计划" // localisation-audit: persisted-value
            planHashtags = ["计划"] // localisation-audit: persisted-value
            readingTitle = "读书" // localisation-audit: persisted-value
            readingNotes = "从第八章开始" // localisation-audit: persisted-value
            readingHashtags = ["阅读"] // localisation-audit: persisted-value
            studyTitle = "复习单词和例句" // localisation-audit: persisted-value
            studyNotes = "用新学的单词写短句" // localisation-audit: persisted-value
            studyHashtags = ["学习"] // localisation-audit: persisted-value
            runTitle = "去跑步" // localisation-audit: persisted-value
            journalTitle = "写日记" // localisation-audit: persisted-value
            tidyTitle = "整理房间" // localisation-audit: persisted-value
            readingMemo = "读完了第八章" // localisation-audit: persisted-value
            reportOutlineMemo = "整理了主要观点" // localisation-audit: persisted-value
            reportFinishMemo = "完善了文字和数据" // localisation-audit: persisted-value
            studyMemo = "复习了单词，并写了例句" // localisation-audit: persisted-value
            runMemo = "轻松跑了5公里" // localisation-audit: persisted-value
            templates = ScreenshotTaskTemplates(
                work: ["整理报告", "回复邮件", "检查资料", "准备会议", "安排本周计划"], // localisation-audit: persisted-value
                study: ["复习单词", "听一段简短对话", "练习语法", "整理笔记", "阅读短文"], // localisation-audit: persisted-value
                reading: ["阅读25页", "阅读小说", "写读书笔记", "读完一章"], // localisation-audit: persisted-value
                health: ["晨跑", "做拉伸", "散步", "力量训练"], // localisation-audit: persisted-value
                personal: ["整理房间", "购买食材", "给家人打电话", "做晚饭", "写日记"], // localisation-audit: persisted-value
                other: ["缴费", "倒垃圾", "整理照片"], // localisation-audit: persisted-value
                memos: ["完成了计划内容", "整理了要点", "确定了下一步", "稳步推进了任务", "复习了难点", "完成了一个阶段"], // localisation-audit: persisted-value
                focusHashtag: "专注" // localisation-audit: persisted-value
            )

        case .zhHant:
            workDirection = "工作" // localisation-audit: persisted-value
            studyDirection = "學習" // localisation-audit: persisted-value
            readingDirection = "閱讀" // localisation-audit: persisted-value
            healthDirection = "健康" // localisation-audit: persisted-value
            personalDirection = "個人生活" // localisation-audit: persisted-value
            otherDirection = "其他" // localisation-audit: persisted-value
            featuredTitle = "完成報告" // localisation-audit: persisted-value
            featuredNotes = "核對重點和數據" // localisation-audit: persisted-value
            featuredHashtags = ["工作", "本週"] // localisation-audit: persisted-value
            emailTitle = "回覆郵件" // localisation-audit: persisted-value
            emailHashtags = ["工作"] // localisation-audit: persisted-value
            planTitle = "安排明天的計畫" // localisation-audit: persisted-value
            planHashtags = ["計畫"] // localisation-audit: persisted-value
            readingTitle = "讀書" // localisation-audit: persisted-value
            readingNotes = "從第八章開始" // localisation-audit: persisted-value
            readingHashtags = ["閱讀"] // localisation-audit: persisted-value
            studyTitle = "複習單字和例句" // localisation-audit: persisted-value
            studyNotes = "用新學的單字寫短句" // localisation-audit: persisted-value
            studyHashtags = ["學習"] // localisation-audit: persisted-value
            runTitle = "去跑步" // localisation-audit: persisted-value
            journalTitle = "寫日記" // localisation-audit: persisted-value
            tidyTitle = "整理房間" // localisation-audit: persisted-value
            readingMemo = "讀完了第八章" // localisation-audit: persisted-value
            reportOutlineMemo = "整理了主要觀點" // localisation-audit: persisted-value
            reportFinishMemo = "完善了文字和數據" // localisation-audit: persisted-value
            studyMemo = "複習了單字，並寫了例句" // localisation-audit: persisted-value
            runMemo = "輕鬆跑了5公里" // localisation-audit: persisted-value
            templates = ScreenshotTaskTemplates(
                work: ["整理報告", "回覆郵件", "檢查資料", "準備會議", "安排本週計畫"], // localisation-audit: persisted-value
                study: ["複習單字", "聽一段簡短對話", "練習文法", "整理筆記", "閱讀短文"], // localisation-audit: persisted-value
                reading: ["閱讀25頁", "閱讀小說", "寫讀書筆記", "讀完一章"], // localisation-audit: persisted-value
                health: ["晨跑", "做伸展", "散步", "肌力訓練"], // localisation-audit: persisted-value
                personal: ["整理房間", "購買食材", "打電話給家人", "做晚餐", "寫日記"], // localisation-audit: persisted-value
                other: ["繳費", "倒垃圾", "整理照片"], // localisation-audit: persisted-value
                memos: ["完成了計畫內容", "整理了重點", "確定了下一步", "穩步推進了任務", "複習了難點", "完成了一個階段"], // localisation-audit: persisted-value
                focusHashtag: "專注" // localisation-audit: persisted-value
            )
        }
    }
}


struct ScreenshotTaskTemplates {
    let work: [String]
    let study: [String]
    let reading: [String]
    let health: [String]
    let personal: [String]
    let other: [String]
    let memos: [String]
    let focusHashtag: String

    func title(for directionID: UUID, index: Int) -> String {
        let values: [String]
        switch directionID {
        case ScreenshotDataSeeder.featuredDirectionID: values = work
        case UUID(uuidString: "10000000-0000-4000-8000-000000000002")!: values = study
        case UUID(uuidString: "10000000-0000-4000-8000-000000000003")!: values = reading
        case UUID(uuidString: "10000000-0000-4000-8000-000000000004")!: values = health
        case UUID(uuidString: "10000000-0000-4000-8000-000000000005")!: values = personal
        default: values = other
        }
        return values[index % values.count]
    }

    func memo(index: Int) -> String {
        memos[index % memos.count]
    }
}
