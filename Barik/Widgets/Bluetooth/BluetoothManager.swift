import Combine
import Foundation
import IOBluetooth

/// Статус Bluetooth устройства
enum DeviceStatus: String {
    case connected
    case disconnected
    case connecting
}

/// Модель Bluetooth устройства
struct BluetoothDevice: Identifiable, Equatable {
    var id: String { address }
    let name: String
    let address: String
    let type: DeviceType
    var status: DeviceStatus

    enum DeviceType: String {
        case headphones
        case keyboard
        case mouse
        case speaker
        case gameController
        case phone
        case watch
        case unknown

        var iconName: String {
            switch self {
            case .headphones: return "headphones"
            case .keyboard: return "keyboard"
            case .mouse: return "computermouse"
            case .speaker: return "speaker.wave.2.fill"
            case .gameController: return "gamecontroller.fill"
            case .phone: return "iphone"
            case .watch: return "applewatch"
            case .unknown: return "questionmark.circle"
            }
        }
    }

    static func detectType(from name: String, minorType: String?) -> DeviceType {
        let lowercaseName = name.lowercased()
        let lowercaseMinorType = minorType?.lowercased()

        if let type = lowercaseMinorType {
            switch type {
            case "headphones", "headset":
                return .headphones
            case "keyboard":
                return .keyboard
            case "mouse":
                return .mouse
            case "speaker":
                return .speaker
            case "gamepad", "controller":
                return .gameController
            case "phone":
                return .phone
            case "watch":
                return .watch
            default:
                print(type)
                break
            }
        }

        if lowercaseName.contains("airpods") || lowercaseName.contains("headphone")
            || lowercaseName.contains("headset") || lowercaseName.contains("buds")
        {
            return .headphones
        }
        if lowercaseName.contains("keyboard") || lowercaseName.contains("клавиатура") {
            return .keyboard
        }
        if lowercaseName.contains("mouse") || lowercaseName.contains("мышь") {
            return .mouse
        }
        if lowercaseName.contains("speaker") || lowercaseName.contains("колонка")
            || lowercaseName.contains("sound") || lowercaseName.contains("станция")
        {
            return .speaker
        }
        if lowercaseName.contains("controller") || lowercaseName.contains("геймпад") {
            return .gameController
        }
        if lowercaseName.contains("iphone") {
            return .phone
        }
        if lowercaseName.contains("watch") {
            return .watch
        }

        return .unknown
    }
}

/// Менеджер для работы с Bluetooth
class BluetoothManager: ObservableObject {
    static let shared = BluetoothManager()

    @Published var isBluetoothEnabled: Bool = false
    @Published var devices: [BluetoothDevice] = []

    private var timer: Timer?

    init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateBluetoothStatus()
        }
        updateBluetoothStatus()
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    /// Обновляет статус Bluetooth и список устройств
    func updateBluetoothStatus() {
        // Проверяем, включен ли Bluetooth
        if IOBluetoothHostController.default() != nil {
            isBluetoothEnabled =
                IOBluetoothHostController.default().powerState
                == kBluetoothHCIPowerStateON
        } else {
            isBluetoothEnabled = false
        }

        fetchDevices()
    }

    /// Получает список устройств с помощью AppleScript
    private func fetchDevices() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            // Получаем все устройства с помощью AppleScript
            let scriptGetAllDevices =
                "do shell script \"/usr/sbin/system_profiler SPBluetoothDataType -json\""

            guard let self = self,
                let fetchedData = try? self.runAppleScript(scriptGetAllDevices),
                let data = fetchedData.data(using: .utf8)
            else { return }

            do {
                // Парсим JSON верхнего уровня
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let bluetoothDataArray = json["SPBluetoothDataType"] as? [[String: Any]]
                else {
                    print("Ошибка: Не удалось распарсить JSON или найти ключ SPBluetoothDataType")
                    DispatchQueue.main.async { self.devices = [] }  // Очищаем список при ошибке
                    return
                }

                var parsedDevices: [BluetoothDevice] = []

                // Итерируем по каждому контроллеру в массиве (обычно один)
                for controllerData in bluetoothDataArray {
                    // Обрабатываем подключенные устройства
                    if let connectedDeviceDicts = controllerData["device_connected"]
                        as? [[String: Any]]
                    {
                        parsedDevices.append(
                            contentsOf: self.parseDeviceDictionaries(
                                connectedDeviceDicts, status: .connected))
                    }

                    // Обрабатываем отключенные устройства
                    if let disconnectedDeviceDicts = controllerData["device_not_connected"]
                        as? [[String: Any]]
                    {
                        parsedDevices.append(
                            contentsOf: self.parseDeviceDictionaries(
                                disconnectedDeviceDicts, status: .disconnected))
                    }
                }

                // Обновляем UI в главном потоке
                DispatchQueue.main.async {
                    // Сохраняем статус connecting для устройств, которые сейчас подключаются
                    let connectingDevices = self.devices.filter { $0.status == .connecting }
                    var finalDevices = parsedDevices

                    for connectingDevice in connectingDevices {
                        if let index = finalDevices.firstIndex(where: {
                            $0.address == connectingDevice.address && $0.status == .disconnected
                        }) {
                            // Если устройство было disconnected, но мы пытались подключиться, сохраняем connecting
                            finalDevices[index].status = .connecting
                        } else if !finalDevices.contains(where: {
                            $0.address == connectingDevice.address && $0.status == .connected
                        }) {
                            // Если устройство пропало или не подключилось, убираем connecting (оно станет disconnected при следующем fetch)
                            // Но пока оставим как есть, чтобы не было скачков
                        }
                        // Если устройство подключилось, оно уже будет иметь статус .connected от parseDeviceDictionaries
                    }

                    // Сортируем: сначала подключенные, потом подключающиеся, потом по имени
                    self.devices = finalDevices.sorted {
                        if $0.status != $1.status {
                            // Сортировка по статусу: connected > connecting > disconnected
                            if $0.status == .connected { return true }
                            if $1.status == .connected { return false }
                            if $0.status == .connecting { return true }
                            if $1.status == .connecting { return false }
                            return false  // Оба disconnected, переходим к имени
                        }
                        return $0.name.lowercased() < $1.name.lowercased()  // Сортировка по имени
                    }
                }

            } catch {
                print("Ошибка при обработке данных Bluetooth: \(error)")
                DispatchQueue.main.async { self.devices = [] }  // Очищаем список при ошибке
            }
        }
    }

    // Вспомогательная функция для парсинга словарей устройств
    private func parseDeviceDictionaries(_ deviceDicts: [[String: Any]], status: DeviceStatus)
        -> [BluetoothDevice]
    {
        var devices: [BluetoothDevice] = []

        for deviceDict in deviceDicts {
            // Ключ словаря - это имя устройства
            if let deviceName = deviceDict.keys.first,
                let deviceInfo = deviceDict[deviceName] as? [String: Any],
                let address = deviceInfo["device_address"] as? String
            {
                // Получаем device_minorType
                let minorType = deviceInfo["device_minorType"] as? String

                let bluetoothDevice = BluetoothDevice(
                    name: deviceName.trimmingCharacters(in: .whitespacesAndNewlines),  // Убираем лишние пробелы в имени
                    address: address,
                    type: BluetoothDevice.detectType(from: deviceName, minorType: minorType),  // Используем обновленную функцию
                    status: status
                )
                devices.append(bluetoothDevice)
            }
        }
        return devices
    }

    /// Запуск AppleScript и получение результата
    private func runAppleScript(_ script: String) throws -> String {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let output = scriptObject.executeAndReturnError(&error)
            if let error = error {
                throw NSError(
                    domain: "BluetoothManagerError", code: 1, userInfo: error as? [String: Any])
            }
            return output.stringValue ?? ""
        }
        throw NSError(domain: "BluetoothManagerError", code: 2, userInfo: nil)
    }

    /// Запуск команды оболочки и получение результата
    private func runShellCommand(_ command: String) throws -> String {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe  // Можно направить ошибки туда же или в отдельный Pipe
        task.arguments = ["-c", command]
        // Путь к оболочке может отличаться, но /bin/zsh или /bin/bash обычно работают
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.standardInput = nil  // Убедимся, что стандартный ввод не используется

        try task.run()  // Запускаем процесс

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        task.waitUntilExit()  // Ждем завершения

        // Проверяем код завершения
        if task.terminationStatus != 0 {
            print("Ошибка выполнения shell команды '\(command)': \(output)")
            throw NSError(
                domain: "ShellCommandError", code: Int(task.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output])
        }

        return output
    }

    /// Подключиться к устройству
    func connectDevice(address: String) {
        // Обновляем статус на .connecting в главном потоке до начала операции
        DispatchQueue.main.async {
            if let index = self.devices.firstIndex(where: { $0.address == address }) {
                self.devices[index].status = .connecting
                // Принудительно обновляем Published свойство, чтобы UI среагировал
                self.objectWillChange.send()
            }
        }

        let formattedAddress = address.uppercased().replacingOccurrences(of: ":", with: "-")

        let script = """
            use framework "IOBluetooth"
            use scripting additions

            on getFirstMatchingDevice(deviceMacAddress)
                repeat with device in (current application's IOBluetoothDevice's pairedDevices() as list)
                    if (device's addressString as string) contains deviceMacAddress then return device
                end repeat
                error "Device not found" number -1728
            end getFirstMatchingDevice

            on connectDevice(device)
                if not (device's isConnected as boolean) then
                    set result to device's openConnection()
                    if result is not 0 then error "Failed to connect" number result
                    delay 0.5 -- Даем время на фактическое подключение
                    return result
                else
                    return 0 -- Уже подключено
                end if
            end connectDevice

            try
                set theDevice to getFirstMatchingDevice("\(formattedAddress)")
                return connectDevice(theDevice)
            on error errStr number errNum
                 return errNum -- Возвращаем код ошибки для отладки
            end try
            """

        DispatchQueue.global(qos: .userInitiated).async {  // Используем userInitiated для быстрой реакции
            var connectionError: Error? = nil
            do {
                let result = try self.runAppleScript(script)
                print("AppleScript connect result: \(result)")  // Логируем результат
                // Если AppleScript вернул не 0, считаем это ошибкой (кроме специфичных кодов)
                if let resultCode = Int(result.trimmingCharacters(in: .whitespacesAndNewlines)),
                    resultCode != 0, resultCode != kIOReturnSuccess
                {
                    // Можно добавить более детальную обработку кодов ошибок IOBluetooth
                    connectionError = NSError(
                        domain: "BluetoothManagerError", code: resultCode,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Ошибка подключения через AppleScript, код: \(resultCode)"
                        ])
                }
            } catch {
                print("Ошибка AppleScript при подключении к устройству: \(error)")
                connectionError = error  // Сохраняем ошибку AppleScript
            }

            // Обновляем статус в любом случае через ~0.5-1 секунду
            // Если подключение удалось, fetchDevices увидит статус connected
            // Если не удалось, fetchDevices увидит disconnected, и статус connecting сбросится
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {  // Небольшая задержка перед обновлением
                self.updateBluetoothStatus()
                if connectionError != nil {
                    // Можно добавить обработку ошибки, например, показать пользователю уведомление
                    print("Финальная ошибка подключения: \(connectionError!)")
                    // Если была ошибка и статус все еще connecting, сбросить на disconnected
                    if let index = self.devices.firstIndex(where: {
                        $0.address == address && $0.status == .connecting
                    }) {
                        self.devices[index].status = .disconnected
                        self.objectWillChange.send()
                    }
                }
            }
        }
    }

    /// Отключиться от устройства
    func disconnectDevice(address: String) {
        // Можно добавить статус .disconnecting по аналогии с .connecting, если нужно
        // Но обычно отключение происходит быстро, и достаточно обновить статус после

        let formattedAddress = address.uppercased().replacingOccurrences(of: ":", with: "-")

        let script = """
            use framework "IOBluetooth"
            use scripting additions

            on getFirstMatchingDevice(deviceMacAddress)
                repeat with device in (current application's IOBluetoothDevice's pairedDevices() as list)
                    if (device's addressString as string) contains deviceMacAddress then return device
                end repeat
                error "Device not found" number -1728
            end getFirstMatchingDevice

            on disconnectDevice(device)
                if (device's isConnected as boolean) then
                    set result to device's closeConnection()
                    if result is not 0 then error "Failed to disconnect" number result
                    delay 0.2
                    return result
                else
                    return 0 -- Уже отключено
                end if
            end disconnectDevice

            try
               set theDevice to getFirstMatchingDevice("\(formattedAddress)")
               return disconnectDevice(theDevice)
            on error errStr number errNum
                return errNum
            end try
            """

        DispatchQueue.global(qos: .userInitiated).async {
            var disconnectionError: Error? = nil
            do {
                let result = try self.runAppleScript(script)
                print("AppleScript disconnect result: \(result)")
                if let resultCode = Int(result.trimmingCharacters(in: .whitespacesAndNewlines)),
                    resultCode != 0, resultCode != kIOReturnSuccess
                {
                    disconnectionError = NSError(
                        domain: "BluetoothManagerError", code: resultCode,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Ошибка отключения через AppleScript, код: \(resultCode)"
                        ])
                }
            } catch {
                print("Ошибка AppleScript при отключении от устройства: \(error)")
                disconnectionError = error
            }
            // Обновляем статус после небольшой задержки
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.updateBluetoothStatus()
                if disconnectionError != nil {
                    print("Финальная ошибка отключения: \(disconnectionError!)")
                    // Дополнительная обработка ошибки при необходимости
                }
            }
        }
    }
}
