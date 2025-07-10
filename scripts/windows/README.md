# Cordelia-I IoT Device Management Tools

A comprehensive set of tools for managing and configuring Cordelia-I EV-Kit devices, designed for IoT cybersecurity workshops and training.

## 📋 Overview

This toolkit provides easy-to-use command-line interfaces for:
- **Wi-Fi Management** - Scan, connect, and manage wireless networks
- **MQTT Connectivity** - Connect to MQTT brokers (TCP, TLS, mTLS)
- **IoT Platform Integration** - Provision and connect to IoT platforms
- **System Management** - Device reboot and factory reset
- **Device Information** - Get comprehensive device status
- **File Management** - Upload/download files to/from the device
- **Configuration Management** - Validate and manage device settings

## 🚀 Quick Start

### Prerequisites
- Windows 10/11 or Windows Server 2016+
- PowerShell 5.0 or later
- .NET Framework 4.5 or later
- Cordelia-I device connected via USB

### Installation
1. Extract the tool package to your preferred directory
2. Connect your Cordelia-I device via USB
3. Navigate to the tools directory
4. Double click on `cordelia-tools.cmd` to start

## 🛠️ Available Tools

### Main Menu (`cordelia-tools.cmd`)
The primary interface providing access to all tools:

```cmd
cordelia-tools.cmd
```

### Individual Tools

#### 1. Wi-Fi Management (`wifi-management.cmd`)
Manage Wi-Fi connections and scan for networks.

**Features:**
- Scan for available networks
- Connect to Wi-Fi with various security types
- Interactive network selection
- View connection status
- Disconnect from current network

**Usage:**
```cmd
wifi-management.cmd
```

**PowerShell Direct Usage:**
```powershell
# Scan for networks
.\wifi-management.ps1 -Action Scan

# Connect to network
.\wifi-management.ps1 -Action Connect -SSID "MyNetwork" -SecurityType WPA_WPA2 -SecurityKey "password"

# Interactive scan and connect
.\wifi-management.ps1 -Action ScanAndConnect

# Check connection status
.\wifi-management.ps1 -Action Status
```

#### 2. MQTT Management (`mqtt-management.cmd`)
Connect to MQTT brokers and manage messaging.

**Features:**
- TCP, TLS, and mTLS connections
- Subscribe to topics
- Publish messages
- Connection status monitoring

**Usage:**
```cmd
mqtt-management.cmd
```

**PowerShell Direct Usage:**
```powershell
# Connect to MQTT broker
.\mqtt-management.ps1 -Action Connect -ConnectionType TCP -Broker "mqtt.example.com" -Port 1883 -ClientId "cordelia-device"

# Subscribe to topic
.\mqtt-management.ps1 -Action Subscribe -Topic "sensors/temperature" -QoS 1

# Publish message
.\mqtt-management.ps1 -Action Publish -Topic "device/status" -Message "online"
```

#### 3. IoT Operations (`iot-operations.cmd`)
Provision and manage IoT platform connections.

**Features:**
- QuarkLink provisioning
- Device registration (AWS, Azure, QuarkLink, Generic)
- Platform configuration
- Device enrollment
- Connection management

**Usage:**
```cmd
iot-operations.cmd
```

**PowerShell Direct Usage:**
```powershell
# Provision for QuarkLink
.\iot-operations.ps1 -Action Provision -Platform QuarkLink -ProvisioningData "config.json"

# Register device
.\iot-operations.ps1 -Action Register -Platform AWS -DeviceId "device-001" -Endpoint "iot.amazonaws.com"

# Connect to platform
.\iot-operations.ps1 -Action Connect -Platform QuarkLink
```

#### 4. System Management (`system-management.cmd`)
Device system operations and maintenance.

**Features:**
- Device reboot
- Factory reset (with safety confirmation)
- System status monitoring

**Usage:**
```cmd
system-management.cmd
```

#### 5. Device Information (`device-info.cmd`)
Get comprehensive device information and status.

**Features:**
- Device identification
- Firmware versions
- Network status
- File system information
- Export device reports

**Usage:**
```cmd
device-info.cmd
```

#### 6. File Manager (`file-manager.cmd`)
Upload and download files to/from the device.

**Features:**
- Upload certificates and files
- Download device files
- File system management
- Progress monitoring

**Usage:**
```cmd
file-manager.cmd
```

#### 7. Configuration Validator (`config-validator.cmd`)
Validate and manage device configuration.

**Features:**
- Configuration file validation
- Setting verification
- Configuration backup/restore

**Usage:**
```cmd
config-validator.cmd
```

#### 8. Certificate Upload (`upload-certificate.cmd`)
Dedicated tool for uploading certificates to the device.

**Features:**
- Certificate file upload
- Validation and verification
- Multiple certificate formats support

**Usage:**
```cmd
upload-certificate.cmd
```

## ⚙️ Configuration

### Main Configuration File (`config.ini`)
Configure device connection settings:

```ini
[UART]
# Serial port settings for Cordelia-I device communication
port = COM5
baudrate = 115200
databits = 8
parity = N
stopbits = 1
timeout = 30

[SECURITY]
# Security and encryption settings
certificate_name = certificate.pem
chunk_size = 512
encoding = ascii
max_retries = 3
verify_upload = true

[FILE_OPERATIONS]
# File operation preferences and limits
confirm_overwrite = true
enable_logging = true
log_directory = ./logs
default_download_dir = ../downloads
read_chunk_size = 512
max_download_size = 10485760

[MQTT]
# MQTT broker settings (if applicable)
broker = your-mqtt-broker.com
port = 8883
client_id = cordelia-device-001
use_tls = true
keepalive = 60
```

### Finding Your COM Port

#### Method 1: Our COM Port Utility
Use our built-in COM port detection utility from multiple tools:

**Option A: Setup Wizard**
1. **Run `cordelia-tools.cmd`**
2. **Select option 9** (Setup Wizard)
3. **View Step 2** - the wizard will automatically scan and display detailed port information

**Option B: Configuration Validator**
1. **Run `cordelia-tools.cmd`**  
2. **Select option 8** (Configuration Validator)
3. **Select option 4** (List available COM ports)

Both utilities will scan and display:
- USB serial devices with detailed descriptions
- All available COM ports on your system
- Hardware-specific identifiers for Cordelia-I devices

The utility will show detailed entries like:
```
USB Serial Devices (likely Cordelia-I candidates):
════════════════════════════════════════════════════════════════
   🔌 COM3 - Silicon Labs CP210x USB to UART Bridge (COM3)
      Hardware ID: USB\VID_10C4&PID_EA60
      ✅ Silicon Labs CP210x - Common for Cordelia-I
   🔌 COM5 - USB Serial Port (COM5)
      Hardware ID: USB\VID_0403&PID_6001
      ✅ FTDI Chip - Alternative driver

All Available COM Ports:
════════════════════════════════════════════════════════════════
   📍 COM1
   📍 COM3
   📍 COM5
```

#### Method 2: Device Manager
1. **Open Device Manager**
   - Right-click "This PC" → Properties → Device Manager
   - Or press `Win + X` → Device Manager
   - Or run `devmgmt.msc` from Start menu

2. **Expand "Ports (COM & LPT)"**
   - Look for entries containing these identifiers:
     - **"Silicon Labs CP210x USB to UART Bridge"** (most common)
     - **"FTDI USB Serial Port"** (alternative driver)
     - **"USB Serial Port"** (generic Windows driver)
     - **"Prolific USB-to-Serial"** (some configurations)

3. **Identify Cordelia-I Device**
   - Right-click on the suspected COM port
   - Select "Properties" → "Details" tab
   - In "Property" dropdown, select "Hardware Ids"
   - Look for these identifiers:
     - `USB\VID_10C4&PID_EA60` (Silicon Labs CP2102/CP2109)
     - `USB\VID_0403&PID_6001` (FTDI FT232)
     - `USB\VID_067B&PID_2303` (Prolific PL2303)

4. **Note the COM port number** (e.g., COM3, COM5, COM7)
5. **Update `config.ini`** with the correct port

#### Troubleshooting COM Port Issues

**No COM Port Visible:**
- Ensure Cordelia-I device is powered on
- Try a different USB cable
- Try a different USB port
- Check if drivers are installed properly

**Multiple COM Ports:**
- Unplug other USB serial devices
- Look for the port that appears/disappears when you connect/disconnect Cordelia-I
- Check Device Manager for device descriptions

**Driver Installation:**
If no COM port appears, you may need to install drivers:
1. **Silicon Labs CP210x Driver** (most common)
   - Download from: https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers
   - Install the appropriate driver for your Windows version

2. **FTDI Driver** (alternative)
   - Download from: https://ftdichip.com/drivers/vcp-drivers/
   - Install if your device uses FTDI chipset

**Testing COM Port:**
After identifying the port, test it with the device info tool:
```cmd
device-info.cmd
```

**Common COM Port Numbers:**
- Usually COM3, COM4, COM5, or higher
- COM1 and COM2 are typically reserved for legacy ports
- Port numbers can change if you use different USB ports

## 🔧 Common Operations

### Setting Up Wi-Fi
1. Run `wifi-management.cmd`
2. Choose "Scan and Connect"
3. Select your network from the list
4. Enter the password when prompted
5. Wait for connection confirmation

### Uploading a Certificate
1. Run `upload-certificate.cmd`
2. Select your certificate file
3. Choose upload method (Base64 recommended)
4. Monitor upload progress
5. Verify successful upload

### Connecting to MQTT
1. Ensure Wi-Fi is connected
2. Run `mqtt-management.cmd`
3. Choose "Connect to Broker"
4. Configure connection settings
5. Test with publish/subscribe

### IoT Platform Setup
1. Run `iot-operations.cmd`
2. Choose "Device Provisioning"
3. Select your IoT platform
4. Follow platform-specific setup
5. Test connection

## 🚨 Troubleshooting

### Common Issues

**Device Not Responding:**
- Check COM port in config.ini
- Verify USB connection
- Try different USB port
- Restart device

**Wi-Fi Connection Fails:**
- Verify network credentials
- Check signal strength
- Ensure network is 2.4GHz
- Try different security settings

**MQTT Connection Issues:**
- Verify broker settings
- Check network connectivity
- Validate certificates (for TLS)
- Review firewall settings

**Certificate Upload Fails:**
- Check file permissions
- Verify certificate format
- Reduce chunk size in config
- Try different encoding

### Debug Mode
Enable detailed logging by setting environment variable:
```cmd
set CORDELIA_DEBUG=1
```

### Log Files
- Tool logs are saved in `./logs/` directory
- Device communication logs available with debug mode
- Upload logs saved with timestamp

## 📚 Advanced Usage

### Batch Operations
Create batch files for common operations:

```cmd
@echo off
echo Connecting to Wi-Fi...
powershell -File wifi-management.ps1 -Action Connect -SSID "MyNetwork" -SecurityType WPA_WPA2 -SecurityKey "password"

echo Connecting to MQTT...
powershell -File mqtt-management.ps1 -Action Connect -Broker "mqtt.example.com" -Port 1883 -ClientId "device-001"

echo Publishing status...
powershell -File mqtt-management.ps1 -Action Publish -Topic "device/status" -Message "online"
```

### Configuration Management
Use different configuration files for different environments:

```cmd
# Development environment
powershell -File wifi-management.ps1 -Action Connect -ConfigPath "config-dev.ini"

# Production environment
powershell -File wifi-management.ps1 -Action Connect -ConfigPath "config-prod.ini"
```

## 🔐 Security Considerations

### Best Practices
- Use secure passwords for Wi-Fi networks
- Implement proper certificate management
- Use TLS/mTLS for MQTT connections
- Regularly update device firmware
- Keep provisioning files secure

### Certificate Management
- Store certificates in secure locations
- Use proper file permissions
- Validate certificate chains
- Monitor certificate expiration

## 🐛 Known Limitations

- Windows-only (PowerShell requirement)
- Serial communication only (no network management)
- Limited to CC3200/CC3220 AT command set
- PowerShell execution policy may require adjustment

## 📖 Additional Resources

### Documentation
- Individual tool help: Run any `.cmd` file with `/?` parameter
- PowerShell help: `Get-Help .\toolname.ps1 -Full`
- AT Command reference: See exercise files in project

### Support
- Check device-specific documentation
- Review AT command specifications
- Consult Würth Elektronik resources
- Check project issues on GitHub

---

**Note**: This toolkit is designed for IoT cybersecurity workshops and educational purposes. For production deployment, consider additional security hardening and testing procedures.