import Carbon
import Combine
import Foundation

/// Модель раскладки клавиатуры
struct KeyboardLayout: Identifiable, Equatable {
    var id: String { id_str }
    let id_str: String
    let name: String
    let localizedName: String
    let isActive: Bool
    let languageCode: String?

    var iconName: String {
        return "globe"
    }

    var shortDisplayName: String {
        // Используем код языка, если он доступен, иначе используем первые 2 символа имени раскладки
        if let code = languageCode {
            return code.uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }

    static func == (lhs: KeyboardLayout, rhs: KeyboardLayout) -> Bool {
        return lhs.id_str == rhs.id_str
    }
}

/// Менеджер для работы с раскладками клавиатуры
class KeyboardLayoutManager: ObservableObject {
    static let shared = KeyboardLayoutManager()

    @Published var layouts: [KeyboardLayout] = []
    @Published var currentLayout: KeyboardLayout?

    private var distributeNotification: DistributedNotificationCenter
    private var layoutObserver: NSObjectProtocol?

    init() {
        self.distributeNotification = DistributedNotificationCenter.default()
        setupLayoutObserver()
        fetchLayouts()
    }

    deinit {
        if let observer = layoutObserver {
            distributeNotification.removeObserver(observer)
        }
    }

    /// Настраивает наблюдатель за изменениями раскладки
    private func setupLayoutObserver() {
        // Отслеживаем изменения раскладки клавиатуры
        layoutObserver = distributeNotification.addObserver(
            forName: NSNotification.Name(
                "com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.fetchLayouts()
        }
    }

    /// Получает список всех доступных раскладок и текущую активную раскладку
    func fetchLayouts() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            var layouts: [KeyboardLayout] = []

            // Получаем текущую раскладку
            guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
            else {
                DispatchQueue.main.async {
                    self.layouts = []
                    self.currentLayout = nil
                }
                return
            }

            // Получаем все доступные раскладки
            let options = [kTISPropertyInputSourceType: kTISTypeKeyboardLayout]
            guard
                let sources = TISCreateInputSourceList(options as CFDictionary, false)?
                    .takeRetainedValue() as? [TISInputSource]
            else {
                DispatchQueue.main.async {
                    self.layouts = []
                    self.currentLayout = nil
                }
                return
            }

            // Получаем ID текущего источника ввода
            let rawCurrentSourceID = TISGetInputSourceProperty(
                currentSource, kTISPropertyInputSourceID)
            let currentSourceID =
                rawCurrentSourceID != nil
                ? Unmanaged<CFString>.fromOpaque(rawCurrentSourceID!).takeUnretainedValue()
                    as String
                : ""

            for source in sources {
                // Получаем ID источника для сравнения с текущим активным
                let rawSourceID = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
                if rawSourceID == nil { continue }

                let sourceID =
                    Unmanaged<CFString>.fromOpaque(rawSourceID!).takeUnretainedValue() as String
                let isActive = sourceID == currentSourceID

                if let layout = self.createLayoutFromSource(source, isActive: isActive) {
                    layouts.append(layout)

                    // Если это активная раскладка, сохраняем её отдельно
                    if layout.isActive {
                        DispatchQueue.main.async {
                            self.currentLayout = layout
                        }
                    }
                }
            }

            // Сортируем раскладки: сначала активная, затем по имени
            let sortedLayouts = layouts.sorted {
                if $0.isActive != $1.isActive {
                    return $0.isActive
                }
                return $0.name.lowercased() < $1.name.lowercased()
            }

            DispatchQueue.main.async {
                self.layouts = sortedLayouts
            }
        }
    }

    /// Создает модель раскладки из источника ввода
    private func createLayoutFromSource(_ source: TISInputSource, isActive: Bool) -> KeyboardLayout?
    {
        // Получаем ID источника
        guard let rawSourceID = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return nil
        }
        let sourceID = Unmanaged<CFString>.fromOpaque(rawSourceID).takeUnretainedValue() as String

        // Получаем локализованное имя
        guard let rawLocalizedName = TISGetInputSourceProperty(source, kTISPropertyLocalizedName)
        else {
            return nil
        }
        let localizedName =
            Unmanaged<CFString>.fromOpaque(rawLocalizedName).takeUnretainedValue() as String

        // Пробуем получить код языка, если есть
        var languageCode: String? = nil

        if let rawLanguages = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) {
            if let languages = Unmanaged<CFArray>.fromOpaque(rawLanguages).takeUnretainedValue()
                as NSArray as? [String],
                let primaryLanguage = languages.first
            {
                // Получаем только первую часть кода языка (например, "en" из "en-US")
                let langParts = primaryLanguage.split(separator: "-")
                languageCode = String(langParts.first ?? "")
            }
        }

        return KeyboardLayout(
            id_str: sourceID,
            name: sourceID,  // Используем ID как имя
            localizedName: localizedName,
            isActive: isActive,
            languageCode: languageCode
        )
    }
}
