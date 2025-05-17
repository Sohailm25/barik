import Combine
import CoreAudio  // Import CoreAudio for audio device management
import Foundation

/// Модель аудиоустройства вывода
struct OutputAudioDevice: Identifiable, Equatable {
    var id: String { uid }  // Use UID as the unique identifier
    let uid: String  // Unique identifier for the audio device
    let name: String
    let manufacturer: String  // Optional: Manufacturer name
    var isActive: Bool  // Is this the currently selected output device?
    var isInput: Bool  // Is this an input device? (Needed for filtering)
    var transportType: UInt32?  // Changed from AudioDeviceTransportType? to UInt32?

    // Helper to get an appropriate system icon name
    var iconName: String {
        if isInput {
            return "mic.fill"  // Default icon for input devices if needed
        }
        // Use CoreAudio constants for comparison
        switch transportType {
        case kAudioDeviceTransportTypeBuiltIn:
            // Try to detect if it's internal speaker specifically
            if name.lowercased().contains("speaker") {
                return "speaker.wave.2.fill"
            } else {
                // Fallback for other built-in types if needed
                return "internaldrive.fill"
            }
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return "headphones"  // Or specific bluetooth icon if available
        case kAudioDeviceTransportTypeAirPlay:
            return "airplayaudio"
        case kAudioDeviceTransportTypeDisplayPort, kAudioDeviceTransportTypeHDMI,
            kAudioDeviceTransportTypeThunderbolt:
            return "display"
        case kAudioDeviceTransportTypeUSB:
            // Check if name suggests headphones/headset for USB devices
            if name.lowercased().contains("headphones") || name.lowercased().contains("headset") {
                return "headphones"
            } else {
                return "speaker.wave.2.fill"  // Default to speaker for other USB audio
            }
        case kAudioDeviceTransportTypeVirtual:
            return "app.connected.to.app.below.fill"  // Icon for virtual devices
        case kAudioDeviceTransportTypePCI, kAudioDeviceTransportTypeFireWire:
            return "hifispeaker.2.fill"  // Icon for internal/external cards
        default:
            return "speaker.wave.2.fill"  // Default speaker icon
        }
    }

    // Equatable conformance
    static func == (lhs: OutputAudioDevice, rhs: OutputAudioDevice) -> Bool {
        return lhs.uid == rhs.uid && lhs.name == rhs.name && lhs.manufacturer == rhs.manufacturer
            && lhs.isActive == rhs.isActive && lhs.isInput == rhs.isInput
            && lhs.transportType == rhs.transportType
    }
}

/// Менеджер для работы с аудиоустройствами вывода
class OutputAudioManager: ObservableObject {
    static let shared = OutputAudioManager()

    @Published var devices: [OutputAudioDevice] = []
    @Published var currentVolume: Float = 0.0  // Добавлено: Текущая громкость

    private var propertyListenerBlock: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var volumeListenerBlock: AudioObjectPropertyListenerBlock?  // Слушатель громкости (главный элемент)
    private var volumeLeftListenerBlock: AudioObjectPropertyListenerBlock?  // Добавлено: Слушатель левого канала
    private var volumeRightListenerBlock: AudioObjectPropertyListenerBlock?  // Добавлено: Слушатель правого канала
    private var isRegisteredForNotifications = false
    private var volumeUpdateTimer: Timer?  // Таймер для предотвращения слишком частых обновлений

    init() {
        setupAudioDeviceListener()
        fetchDevices()  // Initial fetch
        fetchCurrentVolume()  // Добавлено: Получить начальную громкость
        setupVolumeListener()  // Добавлено: Настроить слушатель громкости
    }

    deinit {
        removeAudioDeviceListener()
        removeVolumeListener()  // Удалить слушатель громкости
        volumeUpdateTimer?.invalidate()  // Остановить таймер
    }

    /// Получает и обновляет список аудиоустройств вывода
    func fetchDevices() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            var devices: [OutputAudioDevice] = []
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)

            var dataSize: UInt32 = 0
            var status = AudioObjectGetPropertyDataSize(
                AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)

            if status != kAudioHardwareNoError || dataSize == 0 {
                print("Error getting size of audio devices: \(status)")
                DispatchQueue.main.async { self.devices = [] }
                return
            }

            let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
            var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

            status = AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize,
                &deviceIDs)

            if status != kAudioHardwareNoError {
                print("Error getting audio devices: \(status)")
                DispatchQueue.main.async { self.devices = [] }
                return
            }

            let defaultDeviceID = self.getDefaultOutputDeviceID()

            for deviceID in deviceIDs {
                // Check if it's an output device
                if self.isOutputDevice(deviceID: deviceID) {
                    if let device = self.createDevice(
                        from: deviceID, defaultDeviceID: defaultDeviceID)
                    {
                        // Filter out input devices if needed, or handle them based on requirements
                        // if !device.isInput { // Example filter
                        devices.append(device)
                        // }
                    }
                }
            }

            // Sort devices: Active device first, then by name
            let sortedDevices = devices.sorted {
                if $0.isActive != $1.isActive {
                    return $0.isActive  // true comes first
                }
                return $0.name.lowercased() < $1.name.lowercased()
            }

            DispatchQueue.main.async {
                // Update only if the list has actually changed to avoid unnecessary UI refreshes
                if self.devices != sortedDevices {
                    self.devices = sortedDevices
                }
            }
        }
    }

    /// Creates an OutputAudioDevice struct from an AudioDeviceID
    private func createDevice(from deviceID: AudioDeviceID, defaultDeviceID: AudioDeviceID?)
        -> OutputAudioDevice?
    {
        var deviceName: CFString = "" as CFString
        var deviceUID: CFString = "" as CFString
        var manufacturer: CFString = "" as CFString
        var transportTypeRaw: UInt32 = 0  // Renamed variable
        var dataSize = UInt32(MemoryLayout<CFString?>.size)

        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var manufacturerAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyManufacturer, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var transportTypeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        var status = AudioObjectGetPropertyData(
            deviceID, &nameAddress, 0, nil, &dataSize, &deviceName)
        guard status == kAudioHardwareNoError else {
            print("Failed getting name for \(deviceID): \(status)")
            return nil
        }

        dataSize = UInt32(MemoryLayout<CFString?>.size)
        status = AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &dataSize, &deviceUID)
        guard status == kAudioHardwareNoError else {
            print("Failed getting UID for \(deviceID): \(status)")
            return nil
        }

        dataSize = UInt32(MemoryLayout<CFString?>.size)
        status = AudioObjectGetPropertyData(
            deviceID, &manufacturerAddress, 0, nil, &dataSize, &manufacturer)
        // Manufacturer might fail, it's okay, default to empty string

        dataSize = UInt32(MemoryLayout<UInt32>.size)
        status = AudioObjectGetPropertyData(
            deviceID, &transportTypeAddress, 0, nil, &dataSize, &transportTypeRaw)  // Read into raw UInt32
        let deviceTransportType: UInt32? =
            (status == kAudioHardwareNoError) ? transportTypeRaw : nil  // Assign raw value or nil

        return OutputAudioDevice(
            uid: deviceUID as String,
            name: (deviceName as String).trimmingCharacters(in: .whitespacesAndNewlines),  // Trim whitespace from name
            manufacturer: manufacturer as String,
            isActive: deviceID == defaultDeviceID,
            isInput: hasInputStreams(deviceID: deviceID),  // Check if it has input streams
            transportType: deviceTransportType  // Assign the UInt32?
        )
    }

    /// Checks if a device has output streams
    private func isOutputDevice(deviceID: AudioDeviceID) -> Bool {
        var dataSize: UInt32 = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeOutput,  // Check for output scope
            mElement: kAudioObjectPropertyElementMain)

        let status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        return status == kAudioHardwareNoError && dataSize > 0
    }

    /// Checks if a device has input streams
    private func hasInputStreams(deviceID: AudioDeviceID) -> Bool {
        var dataSize: UInt32 = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput,  // Check for input scope
            mElement: kAudioObjectPropertyElementMain)

        let status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        return status == kAudioHardwareNoError && dataSize > 0
    }

    /// Gets the current default output device ID
    private func getDefaultOutputDeviceID() -> AudioDeviceID? {
        var deviceID: AudioDeviceID = kAudioDeviceUnknown
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceID)

        if status == kAudioHardwareNoError {
            return deviceID
        } else {
            print("Error getting default output device: \(status)")
            return nil
        }
    }

    /// Устанавливает указанное устройство в качестве устройства вывода по умолчанию
    func selectDevice(uid: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Find the device ID for the given UID
            guard let deviceID = self.findDeviceID(byUID: uid) else {
                print("Error: Could not find device ID for UID \(uid)")
                return
            }

            var newDeviceID = deviceID
            var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)

            let status = AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, dataSize,
                &newDeviceID)

            if status != kAudioHardwareNoError {
                print("Error setting default output device: \(status)")
                // TODO: Handle error appropriately (e.g., show alert to user)
            } else {
                print("Successfully set default output device to \(uid)")
                // The listener should automatically trigger fetchDevices() after a short delay
                // Optionally trigger manually if listener seems unreliable
                // DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                //     self.fetchDevices()
                // }
            }
        }
    }

    /// Finds the AudioDeviceID for a given device UID
    private func findDeviceID(byUID uid: String) -> AudioDeviceID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)

        guard status == kAudioHardwareNoError, dataSize > 0 else { return nil }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs
        )
        guard status == kAudioHardwareNoError else { return nil }

        for deviceID in deviceIDs {
            var deviceUIDRef: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString?>.size)
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)

            status = AudioObjectGetPropertyData(
                deviceID, &uidAddress, 0, nil, &uidSize, &deviceUIDRef)
            if status == kAudioHardwareNoError, (deviceUIDRef as String) == uid {
                return deviceID
            }
        }
        return nil  // Not found
    }

    /// Устанавливает слушателя для изменений в аудиоустройствах
    private func setupAudioDeviceListener() {
        guard !isRegisteredForNotifications else { return }

        // Listener for general device list changes (add/remove)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        propertyListenerBlock = { [weak self] (inNumberAddresses, inAddresses) in
            print("Audio devices changed (list).")
            // Use debounce or throttle here if needed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {  // Debounce slightly
                self?.fetchDevices()
            }
        }

        let status1 = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &propertyAddress,
            DispatchQueue.global(qos: .background), propertyListenerBlock!)
        if status1 != noErr {
            print("Error adding listener for device list changes: \(status1)")
        }

        // Listener for default output device change
        var defaultDeviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        defaultDeviceListenerBlock = { [weak self] (inNumberAddresses, inAddresses) in
            print("Default output device changed.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {  // Debounce slightly
                self?.fetchDevices()  // Refetch to update isActive status
                self?.updateVolumeListener()  // Добавлено: Обновить слушатель громкости
            }
        }

        let status2 = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress,
            DispatchQueue.global(qos: .background), defaultDeviceListenerBlock!)
        if status2 != noErr {
            print("Error adding listener for default device change: \(status2)")
        }

        if status1 == noErr && status2 == noErr {
            isRegisteredForNotifications = true
            print("Audio listeners registered.")
        } else {
            // Clean up if one succeeded but the other failed
            removeAudioDeviceListener()
        }
    }

    /// Удаляет слушателя изменений
    private func removeAudioDeviceListener() {
        guard isRegisteredForNotifications, let listenerBlock = propertyListenerBlock,
            let defaultListener = defaultDeviceListenerBlock
        else { return }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var status1 = AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &propertyAddress,
            DispatchQueue.global(qos: .background), listenerBlock)

        var defaultDeviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var status2 = AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &defaultDeviceAddress,
            DispatchQueue.global(qos: .background), defaultListener)

        if status1 != noErr || status2 != noErr {
            print("Error removing audio listener: status1=\(status1), status2=\(status2)")
        } else {
            print("Audio listeners removed.")
        }

        isRegisteredForNotifications = false
        propertyListenerBlock = nil
        defaultDeviceListenerBlock = nil
    }

    // MARK: - Volume Control - Добавлено

    /// Получает текущую громкость системного устройства вывода по умолчанию
    func fetchCurrentVolume() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self, let defaultDeviceID = self.getDefaultOutputDeviceID() else {
                return
            }

            // Здесь будем сохранять лучшее значение громкости, которое удалось получить
            var bestVolume: Float = -1.0

            // Попробуем получить громкость сначала с главного элемента
            do {
                var volume: Float = 0.0
                var dataSize = UInt32(MemoryLayout<Float32>.size)
                var propertyAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioObjectPropertyScopeOutput,
                    mElement: kAudioObjectPropertyElementMain)

                if AudioObjectHasProperty(defaultDeviceID, &propertyAddress) {
                    var isSettable: DarwinBoolean = false
                    AudioObjectIsPropertySettable(defaultDeviceID, &propertyAddress, &isSettable)

                    let status = AudioObjectGetPropertyData(
                        defaultDeviceID, &propertyAddress, 0, nil, &dataSize, &volume)

                    if status == kAudioHardwareNoError {
                        bestVolume = volume
                        // print("Fetched master volume: \(volume)")
                    }
                }
            }

            // Если не удалось получить с главного элемента или для дополнительной проверки,
            // попробуем левый канал (1)
            do {
                var volume: Float = 0.0
                var dataSize = UInt32(MemoryLayout<Float32>.size)
                var propertyAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioObjectPropertyScopeOutput,
                    mElement: 1)  // Левый канал

                if AudioObjectHasProperty(defaultDeviceID, &propertyAddress) {
                    var isSettable: DarwinBoolean = false
                    AudioObjectIsPropertySettable(defaultDeviceID, &propertyAddress, &isSettable)

                    let status = AudioObjectGetPropertyData(
                        defaultDeviceID, &propertyAddress, 0, nil, &dataSize, &volume)

                    if status == kAudioHardwareNoError {
                        // Если раньше не получили громкость или это более удачное значение
                        if bestVolume < 0 || (bestVolume == 0 && volume > 0) {
                            bestVolume = volume
                            // print("Fetched left channel volume: \(volume)")
                        }
                    }
                }
            }

            // И наконец, попробуем правый канал (2)
            do {
                var volume: Float = 0.0
                var dataSize = UInt32(MemoryLayout<Float32>.size)
                var propertyAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioObjectPropertyScopeOutput,
                    mElement: 2)  // Правый канал

                if AudioObjectHasProperty(defaultDeviceID, &propertyAddress) {
                    var isSettable: DarwinBoolean = false
                    AudioObjectIsPropertySettable(defaultDeviceID, &propertyAddress, &isSettable)

                    let status = AudioObjectGetPropertyData(
                        defaultDeviceID, &propertyAddress, 0, nil, &dataSize, &volume)

                    if status == kAudioHardwareNoError {
                        // Если предыдущие методы не дали результата или это более удачное значение
                        if bestVolume < 0 || (bestVolume == 0 && volume > 0) {
                            bestVolume = volume
                            // print("Fetched right channel volume: \(volume)")
                        }
                    }
                }
            }

            // Установим найденное значение, если оно корректное
            if bestVolume >= 0 {
                DispatchQueue.main.async {
                    // Обновляем UI только если значение изменилось значительно,
                    // чтобы избежать "прыжков" слайдера при малых изменениях
                    if abs(self.currentVolume - bestVolume) > 0.001 {
                        self.currentVolume = bestVolume
                    }
                }
            } else {
                // Если не удалось получить громкость ни одним способом
                print("Failed to get volume by any method")
                DispatchQueue.main.async {
                    self.currentVolume = 0.0
                }
            }
        }
    }

    /// Устанавливает громкость системного устройства вывода по умолчанию
    func setVolume(_ volume: Float) {
        // Отменяем предыдущий таймер, если он есть
        volumeUpdateTimer?.invalidate()

        // Устанавливаем новый таймер для вызова установки громкости через короткий промежуток времени (например, 0.1 секунды)
        volumeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) {
            [weak self] _ in
            self?.performVolumeUpdate(volume)
        }
    }

    private func performVolumeUpdate(_ volume: Float) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let defaultDeviceID = self.getDefaultOutputDeviceID() else {
                return
            }

            var newVolume = max(0.0, min(1.0, volume))  // Ограничиваем громкость между 0.0 и 1.0
            var dataSize = UInt32(MemoryLayout<Float32>.size)
            var atLeastOneSuccess = false  // Флаг для отслеживания успешной установки хотя бы одним способом

            // Пытаемся установить на главном элементе
            do {
                var propertyAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioObjectPropertyScopeOutput,
                    mElement: kAudioObjectPropertyElementMain)

                if AudioObjectHasProperty(defaultDeviceID, &propertyAddress) {
                    var isSettable: DarwinBoolean = false
                    let settableStatus = AudioObjectIsPropertySettable(
                        defaultDeviceID, &propertyAddress, &isSettable)

                    if settableStatus == noErr && isSettable.boolValue {
                        let status = AudioObjectSetPropertyData(
                            defaultDeviceID, &propertyAddress, 0, nil, dataSize, &newVolume)

                        if status == noErr {
                            atLeastOneSuccess = true
                            // print("Successfully set master volume to \(newVolume)")
                        }
                    }
                }
            }

            // Пытаемся установить на левом канале (1)
            do {
                var propertyAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioObjectPropertyScopeOutput,
                    mElement: 1)  // Левый канал

                if AudioObjectHasProperty(defaultDeviceID, &propertyAddress) {
                    var isSettable: DarwinBoolean = false
                    let settableStatus = AudioObjectIsPropertySettable(
                        defaultDeviceID, &propertyAddress, &isSettable)

                    if settableStatus == noErr && isSettable.boolValue {
                        let status = AudioObjectSetPropertyData(
                            defaultDeviceID, &propertyAddress, 0, nil, dataSize, &newVolume)

                        if status == noErr {
                            atLeastOneSuccess = true
                            // print("Successfully set left channel volume to \(newVolume)")
                        }
                    }
                }
            }

            // Пытаемся установить на правом канале (2)
            do {
                var propertyAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioObjectPropertyScopeOutput,
                    mElement: 2)  // Правый канал

                if AudioObjectHasProperty(defaultDeviceID, &propertyAddress) {
                    var isSettable: DarwinBoolean = false
                    let settableStatus = AudioObjectIsPropertySettable(
                        defaultDeviceID, &propertyAddress, &isSettable)

                    if settableStatus == noErr && isSettable.boolValue {
                        let status = AudioObjectSetPropertyData(
                            defaultDeviceID, &propertyAddress, 0, nil, dataSize, &newVolume)

                        if status == noErr {
                            atLeastOneSuccess = true
                            // print("Successfully set right channel volume to \(newVolume)")
                        }
                    }
                }
            }

            // Проверяем результат и обновляем UI
            if atLeastOneSuccess {
                // Небольшая задержка перед обновлением UI
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.fetchCurrentVolume()  // Обновляем громкость после установки
                }
            } else {
                print("Failed to set volume on any channel")
                DispatchQueue.main.async {
                    self.fetchCurrentVolume()  // Перечитаем текущую громкость
                }
            }
        }
    }

    /// Удаляет слушателя изменений громкости
    private func removeVolumeListener() {
        guard let defaultDeviceID = getDefaultOutputDeviceID() else { return }

        // Удаляем слушатель для главного элемента
        if let listenerBlock = volumeListenerBlock {
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain)

            let status = AudioObjectRemovePropertyListenerBlock(
                defaultDeviceID, &propertyAddress, DispatchQueue.global(qos: .background),
                listenerBlock
            )

            if status != noErr {
                print("Error removing master volume listener: \(status)")
            }
            volumeListenerBlock = nil
        }

        // Удаляем слушатель для левого канала
        if let listenerBlock = volumeLeftListenerBlock {
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: 1)  // Левый канал

            let status = AudioObjectRemovePropertyListenerBlock(
                defaultDeviceID, &propertyAddress, DispatchQueue.global(qos: .background),
                listenerBlock
            )
            volumeLeftListenerBlock = nil
        }

        // Удаляем слушатель для правого канала
        if let listenerBlock = volumeRightListenerBlock {
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: 2)  // Правый канал

            let status = AudioObjectRemovePropertyListenerBlock(
                defaultDeviceID, &propertyAddress, DispatchQueue.global(qos: .background),
                listenerBlock
            )
            volumeRightListenerBlock = nil
        }
    }

    /// Устанавливает слушателя для изменений громкости
    private func setupVolumeListener() {
        guard let defaultDeviceID = getDefaultOutputDeviceID() else {
            print("Cannot setup volume listener: No default output device ID.")
            return
        }

        // Добавляем слушатель для главного элемента
        do {
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain)

            volumeListenerBlock = { [weak self] (_, _) in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.fetchCurrentVolume()
                }
            }

            if AudioObjectHasProperty(defaultDeviceID, &propertyAddress) {
                let status = AudioObjectAddPropertyListenerBlock(
                    defaultDeviceID, &propertyAddress,
                    DispatchQueue.global(qos: .background), volumeListenerBlock!)

                if status != noErr {
                    print("Error adding master volume listener: \(status)")
                    volumeListenerBlock = nil
                }
            }
        }

        // Добавляем слушатель для левого канала (1)
        do {
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: 1)  // Левый канал

            volumeLeftListenerBlock = { [weak self] (_, _) in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.fetchCurrentVolume()
                }
            }

            if AudioObjectHasProperty(defaultDeviceID, &propertyAddress) {
                let status = AudioObjectAddPropertyListenerBlock(
                    defaultDeviceID, &propertyAddress,
                    DispatchQueue.global(qos: .background), volumeLeftListenerBlock!)

                if status != noErr {
                    print("Error adding left channel volume listener: \(status)")
                    volumeLeftListenerBlock = nil
                }
            }
        }

        // Добавляем слушатель для правого канала (2)
        do {
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: 2)  // Правый канал

            volumeRightListenerBlock = { [weak self] (_, _) in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.fetchCurrentVolume()
                }
            }

            if AudioObjectHasProperty(defaultDeviceID, &propertyAddress) {
                let status = AudioObjectAddPropertyListenerBlock(
                    defaultDeviceID, &propertyAddress,
                    DispatchQueue.global(qos: .background), volumeRightListenerBlock!)

                if status != noErr {
                    print("Error adding right channel volume listener: \(status)")
                    volumeRightListenerBlock = nil
                }
            }
        }
    }

    /// Обновляет слушатель громкости при смене устройства по умолчанию
    private func updateVolumeListener() {
        removeVolumeListener()
        setupVolumeListener()
        fetchCurrentVolume()  // Обновляем громкость для нового устройства
    }
}
