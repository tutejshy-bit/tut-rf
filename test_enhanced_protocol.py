#!/usr/bin/env python3
"""
ESP32 Enhanced Protocol Test Script

This script tests the enhanced binary protocol with chunking support
by sending various commands to the ESP32 and verifying responses.
"""

import serial
import time
import struct
import json

class ESP32ProtocolTester:
    def __init__(self, port='COM8', baudrate=115200):
        self.port = port
        self.baudrate = baudrate
        self.serial_conn = None
        
    def connect(self):
        """Connect to ESP32 via serial"""
        try:
            self.serial_conn = serial.Serial(self.port, self.baudrate, timeout=1)
            print(f"✅ Connected to ESP32 on {self.port}")
            return True
        except Exception as e:
            print(f"❌ Failed to connect to ESP32: {e}")
            return False
    
    def disconnect(self):
        """Disconnect from ESP32"""
        if self.serial_conn:
            self.serial_conn.close()
            print("🔌 Disconnected from ESP32")
    
    def create_enhanced_packet(self, message_type, payload=b''):
        """Create enhanced protocol packet"""
        # Enhanced format: [Magic:1][Type:1][ChunkID:1][ChunkNum:1][TotalChunks:1][DataLen:1][Data:variable][Checksum:1]
        magic = 0xAA
        packet_type = 0x01  # DATA
        chunk_id = 0x00    # Single packet
        chunk_num = 0x01    # First chunk
        total_chunks = 0x01 # Single packet
        data_len = len(payload) + 1  # +1 for message type
        
        # Create packet
        packet = bytearray()
        packet.append(magic)
        packet.append(packet_type)
        packet.append(chunk_id)
        packet.append(chunk_num)
        packet.append(total_chunks)
        packet.append(data_len)
        packet.append(message_type)  # Message type
        packet.extend(payload)
        
        # Calculate XOR checksum
        checksum = 0
        for byte in packet:
            checksum ^= byte
        packet.append(checksum)
        
        return bytes(packet)
    
    def send_command(self, message_type, payload=b''):
        """Send command to ESP32"""
        packet = self.create_enhanced_packet(message_type, payload)
        print(f"📤 Sending command 0x{message_type:02X}: {len(packet)} bytes")
        print(f"   Packet: {' '.join(f'{b:02X}' for b in packet)}")
        
        if self.serial_conn:
            self.serial_conn.write(packet)
            self.serial_conn.flush()
            return True
        return False
    
    def read_response(self, timeout=2):
        """Read response from ESP32"""
        if not self.serial_conn:
            return None
            
        start_time = time.time()
        response = bytearray()
        
        while time.time() - start_time < timeout:
            if self.serial_conn.in_waiting > 0:
                data = self.serial_conn.read(self.serial_conn.in_waiting)
                response.extend(data)
                
                # Check if we have a complete packet
                if len(response) >= 7:  # Minimum packet size
                    magic = response[0]
                    if magic == 0xAA:
                        packet_type = response[1]
                        chunk_id = response[2]
                        chunk_num = response[3]
                        total_chunks = response[4]
                        data_len = response[5]
                        
                        expected_len = 6 + data_len + 1  # header + data + checksum
                        if len(response) >= expected_len:
                            # Complete packet received
                            packet = response[:expected_len]
                            remaining = response[expected_len:]
                            response = remaining
                            
                            print(f"📥 Received response: {len(packet)} bytes")
                            print(f"   Packet: {' '.join(f'{b:02X}' for b in packet)}")
                            
                            # Parse response
                            self.parse_response(packet)
                            
                            if len(response) == 0:
                                break
        
        return response
    
    def parse_response(self, packet):
        """Parse enhanced protocol response"""
        if len(packet) < 7:
            print("❌ Invalid packet length")
            return
            
        magic = packet[0]
        packet_type = packet[1]
        chunk_id = packet[2]
        chunk_num = packet[3]
        total_chunks = packet[4]
        data_len = packet[5]
        
        print(f"   Magic: 0x{magic:02X}")
        print(f"   Type: 0x{packet_type:02X}")
        print(f"   ChunkID: {chunk_id}")
        print(f"   ChunkNum: {chunk_num}/{total_chunks}")
        print(f"   DataLen: {data_len}")
        
        if magic != 0xAA:
            print("❌ Invalid magic byte")
            return
            
        if packet_type != 0x01:
            print("❌ Invalid packet type")
            return
            
        # Extract data
        data_start = 6
        data_end = data_start + data_len
        checksum_pos = data_end
        
        if len(packet) < checksum_pos + 1:
            print("❌ Packet too short for checksum")
            return
            
        data = packet[data_start:data_end]
        received_checksum = packet[checksum_pos]
        
        # Verify checksum
        calculated_checksum = 0
        for i in range(checksum_pos):
            calculated_checksum ^= packet[i]
            
        if received_checksum != calculated_checksum:
            print(f"❌ Checksum mismatch: received 0x{received_checksum:02X}, calculated 0x{calculated_checksum:02X}")
            return
        
        print(f"✅ Checksum verified")
        
        # Try to parse as JSON
        try:
            json_str = data.decode('utf-8')
            print(f"📄 Response data: {json_str}")
            try:
                json_data = json.loads(json_str)
                print(f"📋 Parsed JSON: {json_data}")
            except:
                print("📝 Plain text response")
        except:
            print(f"📄 Binary data: {' '.join(f'{b:02X}' for b in data)}")
    
    def test_get_state(self):
        """Test getState command"""
        print("\n🧪 Testing getState command...")
        self.send_command(0x01)  # getState
        self.read_response()
    
    def test_request_scan(self):
        """Test requestScan command"""
        print("\n🧪 Testing requestScan command...")
        # requestScan: minRssi (-100), module (0)
        payload = struct.pack('<iB', -100, 0)  # 4 bytes minRssi + 1 byte module
        self.send_command(0x02, payload)  # requestScan
        self.read_response()
    
    def test_get_files_list(self):
        """Test getFilesList command"""
        print("\n🧪 Testing getFilesList command...")
        # getFilesList: path "/"
        payload = b"/"
        self.send_command(0x05, payload)  # getFilesList
        self.read_response()
    
    def run_tests(self):
        """Run all protocol tests"""
        print("🚀 ESP32 Enhanced Protocol Test Suite")
        print("=" * 50)
        
        if not self.connect():
            return
        
        try:
            # Wait for ESP32 to initialize
            print("⏳ Waiting for ESP32 to initialize...")
            time.sleep(3)
            
            # Run tests
            self.test_get_state()
            time.sleep(1)
            
            self.test_request_scan()
            time.sleep(1)
            
            self.test_get_files_list()
            time.sleep(1)
            
            print("\n✅ All tests completed!")
            
        except KeyboardInterrupt:
            print("\n⏹️ Tests interrupted by user")
        except Exception as e:
            print(f"\n❌ Test error: {e}")
        finally:
            self.disconnect()

if __name__ == "__main__":
    tester = ESP32ProtocolTester()
    tester.run_tests()
