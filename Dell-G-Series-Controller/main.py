#!/bin/python
import os
import re
import sys
import pexpect
import tempfile
from pathlib import Path

import awelc
import PySide6
from PySide6.QtCore import (QSettings, QTimer)
from PySide6.QtGui import (QIcon, QAction)
from PySide6.QtWidgets import (QColorDialog, QMessageBox,QGridLayout, QGroupBox, QWidget, QPushButton, QApplication,
                               QVBoxLayout, QHBoxLayout, QDialog, QSlider, QLabel, QSystemTrayIcon, QMenu, QComboBox)
from patch import g15_5530_patch
from patch import g15_5520_patch
from patch import g15_5515_patch
from patch import g15_5511_patch
from patch import g16_7630_patch


def _acpi_id_eq(got, expect):
    """Compare ACPI model id strings; firmware may vary 0x12C0 vs 0x12c0."""
    if got is None or expect is None:
        return False
    got, expect = str(got).strip(), str(expect).strip()
    if not got or not expect:
        return False
    try:
        return int(got, 0) == int(expect, 0)
    except ValueError:
        return got.lower() == expect.lower()


def _awelc_usb_available():
    """Alienware / Dell RGB via pyusb (187c:0550 / 0551). Without it, awelc calls throw — Qt may hide those errors in slots."""
    try:
        import usb.core
        for pid in (0x0550, 0x0551):
            if usb.core.find(idVendor=0x187C, idProduct=pid) is not None:
                return True
    except Exception:
        pass
    return False


def _app_icon():
    p = Path(__file__).resolve().parent / "window.png"
    if p.is_file():
        return QIcon(str(p))
    return QIcon.fromTheme("video-display", QIcon.fromTheme("computer"))


def _int_from_acpi(v):
    """Coerce acpi_call / parse_shell_exec values (str '0x..', int, bytes) for math/display."""
    if v is None:
        return 0
    if isinstance(v, int):
        return v
    if isinstance(v, (bytes, bytearray)):
        s = v.decode("ascii", errors="replace").strip()
    else:
        s = str(v).strip()
    if not s:
        return 0
    return int(s, 0)


# pty/polkit output often has no \x00 after the hex; only \r\x00... works in that case.
_RE_CSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


def _strip_ansi_sgr(s: str) -> str:
    if not s:
        return s
    return _RE_CSI.sub("", s)


def _try_parse_acpi_line(line: str):
    """
    Parse one line from the elevated shell: original cr..nul slice, or a lone 0x.. value
    (e.g. before a prompt) when nul is missing.
    """
    if not line:
        return None
    cr, nul = line.find("\r"), line.find("\x00")
    if cr != -1 and nul != -1 and nul > cr + 1:
        val = line[cr + 1 : nul].strip()
        if val and not val.lower().startswith("error"):
            return val
    # Skip echoed ACPI invocations (many 0x bytes in one line)
    if "WMAX" in line or (line.count("{") > 0 and line.count("0x") > 1):
        return None
    clean = _strip_ansi_sgr(line).strip()
    if not clean:
        return None
    m = re.match(r"^(0x[0-9a-fA-F]+)\b", clean)
    if m:
        return m.group(1)
    if clean.count("0x") == 1:
        m2 = re.search(r"(0x[0-9a-fA-F]+)\b", clean)
        if m2:
            return m2.group(1)
    return None


def _dmi_read_file(path: str) -> str:
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read().strip()
    except OSError:
        return ""


def _dmi_combined():
    """Dell often splits model across product_name, product_version, etc."""
    keys = [
        "sys_vendor",
        "product_family",
        "product_name",
        "product_version",
        "product_sku",
        "board_vendor",
        "board_name",
    ]
    base = "/sys/class/dmi/id"
    parts = [ _dmi_read_file(f"{base}/{k}") for k in keys ]
    return " ".join(p for p in parts if p).strip()


def _dmi_looks_like_g15_5525(s: str) -> bool:
    if not s or "5525" not in s or "5520" in s:
        return False
    s_up = s.upper()
    if "G15" in s_up and "5525" in s:
        return True
    if re.search(r"G[\s\-.]*15", s, re.I) and "5525" in s:
        return True
    return False


def _dmi_looks_like_g15_5520(s: str) -> bool:
    if not s or "5520" not in s:
        return False
    s_up = s.upper()
    if "G15" in s_up and "5520" in s:
        return True
    if re.search(r"G[\s\-.]*15", s, re.I) and "5520" in s:
        return True
    return False


class MainWindow(QWidget):

    def __init__(self, parent=None):
        super(MainWindow, self).__init__(parent)
        self.is_dell_g_series = False
        self.is_keyboard_supported = True # True by default, in case of no root access, keyboard lights should be adjustable.
        self.model = 'Unknown'
        try:
            self.logfile = open("/tmp/dell-g-series-controller.log","w")
            sys.stdout = self.logfile
        except:
            print("Exception trying to open /tmp/dell-g-series-controller.log")
            exit()
        print("Log file:{}".format(self.logfile))
        self.logfile.write("test")
        self.init_acpi_call()
        self.setMinimumWidth(600)
        self.setWindowTitle("Dell G Series Controller")
        # Read last choices from QSettings
        self.settings = QSettings('Dell-G15', 'Controller')
        #Create grid layout
        grid = QGridLayout()
        self.timer = None
        grid.addWidget(QLabel(f'Device Model:'), 0, 0)
        grid.addWidget(QLabel(f'Dell {self.model}' if self.model != 'Unknown' else self.model), 0, 1)
        grid.addWidget(self._create_first_exclusive_group(), 1, 0)
        if (self.is_root and self.is_dell_g_series):
            grid.addWidget(self._create_second_exclusive_group(), 1, 1)
            self.timer = QTimer(self)    #timer to update fan rpm values
            self.timer.setInterval(1000)
            self.timer.timeout.connect(self.get_rpm_and_temp)
            self.timer.start()
        self.setLayout(grid)

    def init_acpi_call(self):
        self.power_modes_dict = {
            "USTT_Balanced" : "0xa0",
            "USTT_Performance" : "0xa1",
            # "USTT_Cool" : "0xa2",   #Does not work
            "USTT_Quiet" : "0xa3",
            "USTT_FullSpeed": "0xa4",
            "USTT_BatterySaver" : "0xa5",
            "G Mode" : "0xab",
            "Manual" : "0x0",
        }
            
        self.acpi_call_dict = {
            "get_laptop_model" : ["0x1a", "0x02", "0x02"],
            "get_power_mode" : ["0x14", "0x0b", "0x00"],
            "set_power_mode" : ["0x15", "0x01"],    #To be used with a parameter
            "toggle_G_mode" : ["0x25", "0x01"],
            "get_G_mode" : ["0x25", "0x02"],
            "set_fan1_boost" : ["0x15", "0x02", "0x32"],            #To be used with a parameter
            "get_fan1_boost" : ["0x14", "0x0c", "0x32"],
            "get_fan1_rpm" : ["0x14", "0x05", "0x32"],
            "get_cpu_temp" : ["0x14", "0x04", "0x01"],
            "set_fan2_boost" : ["0x15", "0x02", "0x33"],            #To be used with a parameter
            "get_fan2_boost" : ["0x14", "0x0c", "0x33"],
            "get_fan2_rpm" : ["0x14", "0x05", "0x33"],
            "get_gpu_temp" : ["0x14", "0x04", "0x06"]
        }
        
        print("Attempting to create elevated bash subprocess.")
        # NixOS: setuid pkexec lives in /run/wrappers; nix-store pkexec cannot elevate.
        pkexec_bin = "/run/wrappers/bin/pkexec" if os.path.isfile("/run/wrappers/bin/pkexec") else "pkexec"
        # Polkit can take a while; user must click the auth dialog.
        pexpect_timeouts = 300
        # Preserve session env so polkit agent can show a GUI prompt (DISPLAY / WAYLAND / DBUS).
        self.shell = pexpect.spawn(
            "bash",
            encoding="utf-8",
            logfile=self.logfile,
            env=os.environ.copy(),
            args=["--noprofile", "--norc"],
            timeout=pexpect_timeouts,
        )
        self.shell.expect("[#$] ", timeout=pexpect_timeouts)
        self.shell_exec(" export HISTFILE=/dev/null; history -c")
        # Elevate privileges (polkit pkexec — approve the prompt for power/ACPI features)
        self.shell_exec(f"{pkexec_bin} bash --noprofile --norc")
        self.shell_exec(" export HISTFILE=/dev/null; history -c")
        #Check if root or not
        self.is_root = (self.shell_exec("whoami")[1].find("root") != -1)
        if not self.is_root:
            print("Bash shell is NOT root. Disabling ACPI methods...")
            QMessageBox.warning(
                self,
                "No root access",
                "Power and fan features need a privileged shell (polkit / pkexec).\n\n"
                "On NixOS: use Foot or Kitty (not a sandboxed IDE terminal), ensure "
                "polkit-gnome is running, approve the password dialog when the app starts, "
                "then try again. Log: /tmp/dell-g-series-controller.log",
            )
            return

        print("Sh shell is root. Enabling ACPI methods...")

        if not os.path.exists("/proc/acpi/call"):
            QMessageBox.critical(
                self,
                "acpi_call missing",
                "/proc/acpi/call is not available. Load the module, then relaunch:\n\n"
                "  sudo modprobe acpi_call\n\n"
                "On NixOS with iNiR, enable programs.inir.dellGSeries (boot.kernelModules) "
                "and rebuild if needed, then reboot.",
            )
            return

        self._check_laptop_model()

        if self.is_dell_g_series:
            print("Laptop model is supported.")
        else:
            choice = QMessageBox.question(
                self,
                "Unrecognized laptop",
                "WMAX get_laptop_model did not match the built-in table, and DMI did not match "
                "a known G15 model. Try experimental G15 5525-style ACPI? You might damage your "
                "hardware. See /tmp/dell-g-series-controller.log and DMI_combined in the log.",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            )
            self.is_dell_g_series = (choice == QMessageBox.StandardButton.Yes) #User override
    
    def _check_laptop_model(self):
        """Check for supported laptop model"""

        # G15 5525 (AMD): DMI is more reliable than WMAX get_laptop_model on some BIOS builds;
        # also avoids 0x0 on the Intel path being mis-taken for G15 5530.
        dmi0 = _dmi_combined()
        if _dmi_looks_like_g15_5525(dmi0):
            self.acpi_cmd = (
                "echo \"\\_SB.AMW3.WMAX 0 {} {{{}, {}, {}, 0x00}}\" | tee /proc/acpi/call; "
                "cat /proc/acpi/call"
            )
            self.is_dell_g_series = True
            self.is_keyboard_supported = True
            self.model = "G15 5525"
            print("DMI: Dell G15 5525 from {!r} (AMW3; skipping WMAX id table).".format(dmi0))
            return

        # G15 5520 (Intel): product_name is often "Dell G15 5520" — WMAX id can still mismatch.
        if _dmi_looks_like_g15_5520(dmi0):
            self.acpi_cmd = (
                "echo \"\\_SB.AMWW.WMAX 0 {} {{{}, {}, {}, 0x00}}\" | tee /proc/acpi/call; "
                "cat /proc/acpi/call"
            )
            self.is_dell_g_series = True
            self.is_keyboard_supported = True
            self.model = "G15 5520"
            g15_5520_patch(self)
            print("DMI: Dell G15 5520 from {!r} (AMWW; skipping WMAX id table).".format(dmi0))
            return

        # Detect Intel models
        self.acpi_cmd = "echo \"\\_SB.AMWW.WMAX 0 {} {{{}, {}, {}, 0x00}}\" | tee /proc/acpi/call; cat /proc/acpi/call"
        laptop_model=self.acpi_call("get_laptop_model")
        
        # Check if G15 5530
        if _acpi_id_eq(laptop_model, "0x0"):
            # TODO - VERIFY-ME - Is "0x0" really the expected response, or should we use a different ACPI call for this model?
            print("Detected dell g15 5530. Laptop model: 0x{}".format(laptop_model))
            self.is_dell_g_series = True
            self.is_keyboard_supported = True
            self.model = "G15 5530"
            g15_5530_patch(self)
            return

        # Check if G15 5520
        if _acpi_id_eq(laptop_model, "0x12c0"):
            print("Detected dell g15 5520. Laptop model: 0x{}".format(laptop_model))
            self.is_dell_g_series = True
            self.is_keyboard_supported = True
            self.model = "G15 5520"
            g15_5520_patch(self)
            return

        # Check if G15 5511
        if _acpi_id_eq(laptop_model, "0xc80"):
            print("Detected dell g15 5511. Laptop model: 0x{}".format(laptop_model))
            self.is_dell_g_series = True
            self.is_keyboard_supported = True
            self.model = "G15 5511"
            g15_5511_patch(self)
            return

        # Check if G16 7630
        if _acpi_id_eq(laptop_model, "0x0"):
            # TODO - VERIFY-ME - Is "0x0" really the expected response, or should we use a different ACPI call for this model?
            print("Detected dell g16 7630. Laptop model: 0x{}".format(laptop_model))
            self.is_dell_g_series = True
            self.is_keyboard_supported = False
            self.model = "G16 7630"
            g16_7630_patch(self)
            return 

        # Detect AMD models
        self.acpi_cmd = "echo \"\\_SB.AMW3.WMAX 0 {} {{{}, {}, {}, 0x00}}\" | tee /proc/acpi/call; cat /proc/acpi/call"
        laptop_model=self.acpi_call("get_laptop_model")

        # Check if G15 5525
        if _acpi_id_eq(laptop_model, "0x12c0"):
            print("Detected dell g15 5525. Laptop model: 0x{}".format(laptop_model))
            self.is_dell_g_series = True
            self.is_keyboard_supported = True
            self.model = "G15 5525"
            return

        # Check if G15 5515
        if _acpi_id_eq(laptop_model, "0xc80"):
            print("Detected dell g15 5515. Laptop model: 0x{}".format(laptop_model))
            self.is_dell_g_series = True
            self.is_keyboard_supported = True
            self.model = "G15 5515"
            g15_5515_patch(self)
            return

        if dmi0 and not self.is_dell_g_series:
            print(
                "Unrecognized WMAX get_laptop_model id after Intel+AMD: {!r} DMI_combined={!r}".format(
                    laptop_model,
                    dmi0,
                )
            )

    def _create_first_exclusive_group(self):
        groupBox = QGroupBox("Keyboard Led")
        vbox = QVBoxLayout()
        if self.is_keyboard_supported:
            self.state = (self.settings.value("State", "Off"))
            # Create widgets
            self.red_label = QLabel("Red Static")
            self.red = QSlider(orientation=PySide6.QtCore.Qt.Orientation(0x01))
            self.red.setMinimum(0)
            self.red.setMaximum(255)
            self.red.setMinimumSize(100,0)
            self.red.setValue(int(self.settings.value("Red Static", 122)))
            self.red_morph_label = QLabel("Red Morph")
            self.red_morph = QSlider(orientation=PySide6.QtCore.Qt.Orientation(0x01))
            self.red_morph.setMinimum(0)
            self.red_morph.setMaximum(255)
            self.red_morph.setMinimumSize(100,0)
            self.red_morph.setValue(int(self.settings.value("Red Morph", 122)))
            self.green_label = QLabel("Green Static")
            self.green = QSlider(orientation=PySide6.QtCore.Qt.Orientation(0x01))
            self.green.setMinimum(0)
            self.green.setMaximum(255)
            self.green.setMinimumSize(100,0)
            self.green.setValue(int(self.settings.value("Green", 122)))
            self.green_morph_label = QLabel("Green Morph")
            self.green_morph = QSlider(orientation=PySide6.QtCore.Qt.Orientation(0x01))
            self.green_morph.setMinimum(0)
            self.green_morph.setMaximum(255)
            self.green_morph.setMinimumSize(100,0)
            self.green_morph.setValue(int(self.settings.value("Green Morph", 122)))
            self.blue_label = QLabel("Blue Static")
            self.blue = QSlider(orientation=PySide6.QtCore.Qt.Orientation(0x01))
            self.blue.setMinimum(0)
            self.blue.setMaximum(255)
            self.blue.setMinimumSize(100,0)
            self.blue.setValue(int(self.settings.value("Blue Static", 122)))
            self.blue_morph_label = QLabel("Blue Morph")
            self.blue_morph = QSlider(orientation=PySide6.QtCore.Qt.Orientation(0x01))
            self.blue_morph.setMinimum(0)
            self.blue_morph.setMaximum(255)
            self.blue_morph.setMinimumSize(100,0)
            self.blue_morph.setValue(int(self.settings.value("Blue Morph", 122)))
            self.duration_label = QLabel("Duration")
            self.duration = QSlider(orientation=PySide6.QtCore.Qt.Orientation(0x01))
            self.duration.setMinimum(0x4)
            self.duration.setMaximum(0xfff)
            self.duration.setMinimumSize(100,0)
            self.duration.setValue(int(self.settings.value("Duration", 255)))
            widget = QWidget()
            hbox = QHBoxLayout(widget)
            self.combobox_mode = QComboBox()
            self.combobox_mode.addItems(["Static Color", "Morph", "Color and Morph", "Off"])
            self.combobox_mode.setCurrentText(self.settings.value("Action", "Static Color"))

            self.button_apply = QPushButton("Apply")
            hbox.addWidget(self.combobox_mode)
            hbox.addWidget(self.button_apply)

            # Add widgets to layout
            vbox.addWidget(self.red_label)
            vbox.addWidget(self.red)
            vbox.addWidget(self.red_morph_label)
            vbox.addWidget(self.red_morph)
            vbox.addWidget(self.green_label)
            vbox.addWidget(self.green)
            vbox.addWidget(self.green_morph_label)
            vbox.addWidget(self.green_morph)
            vbox.addWidget(self.blue_label)
            vbox.addWidget(self.blue)
            vbox.addWidget(self.blue_morph_label)
            vbox.addWidget(self.blue_morph)
            vbox.addWidget(self.duration_label)
            vbox.addWidget(self.duration)
            vbox.addWidget(widget)

            # Add button callbacks
            self.combobox_mode.currentTextChanged.connect(self.combobox_choice)
            self.button_apply.clicked.connect(self.apply_leds)

        else:
            label = QLabel("Keyboard support not currently available for this model")
            label.setWordWrap(True)
            vbox.addWidget(label)
        #Return
        groupBox.setLayout(vbox)
        return groupBox


    def _create_second_exclusive_group(self):
        groupBox = QGroupBox("Power and Fans")
        vbox = QVBoxLayout()
        
        widget = QWidget()
        hbox = QHBoxLayout(widget)
        
        #Power mode choice and Apply button
        self.combobox_mode_power = QComboBox()
        self.combobox_mode_power.addItems(self.power_modes_dict.keys())
        self.combobox_mode_power.setCurrentText(self.settings.value("Power", "USTT_Balanced"))
        self.info_label = QLabel("")
        self.info_label.setWordWrap(True)
        
        #Fan 1 RPM
        self.fan1_label = QLabel("CPU Fan Boost")
        widget_fan1 = QWidget()
        hbox_fan1 = QHBoxLayout(widget_fan1)
        self.fan1_boost = QSlider(orientation=PySide6.QtCore.Qt.Orientation(0x01))
        self.fan1_boost.setMinimum(0x00)
        self.fan1_boost.setMaximum(0xff)
        self.fan1_boost.setMinimumSize(100,0)
        self.fan1_boost.setTickPosition(QSlider.TickPosition.TicksBelow)
        self.fan1_boost.setTickInterval(25.5)   #10 steps
        self.fan1_boost.setValue(int(self.settings.value("Fan1 Boost", 0x00)))
        self.fan1_current = QLabel("0 RPM")
        hbox_fan1.addWidget(self.fan1_boost)
        hbox_fan1.addWidget(self.fan1_current)

        #Fan 2 RPM
        self.fan2_label = QLabel("GPU Fan Boost")
        widget_fan2 = QWidget()
        hbox_fan2 = QHBoxLayout(widget_fan2)
        self.fan2_boost = QSlider(orientation=PySide6.QtCore.Qt.Orientation(0x01))
        self.fan2_boost.setMinimum(0x00)
        self.fan2_boost.setMaximum(0xff)
        self.fan2_boost.setMinimumSize(100,0)
        self.fan2_boost.setTickPosition(QSlider.TickPosition.TicksBelow)
        self.fan2_boost.setTickInterval(25.5)   #10 steps
        self.fan2_boost.setValue(int(self.settings.value("Fan2 Boost", 0x00)))
        self.fan2_current = QLabel("0 RPM")
        hbox_fan2.addWidget(self.fan2_boost)
        hbox_fan2.addWidget(self.fan2_current)

        #Add widgets to layout
        vbox.addWidget(self.combobox_mode_power)
        vbox.addWidget(self.fan1_label)
        vbox.addWidget(widget_fan1)
        vbox.addWidget(self.fan2_label)
        vbox.addWidget(widget_fan2)
        vbox.addWidget(self.info_label)
        
        # Add button callbacks
        self.combobox_mode_power.currentTextChanged.connect(self.combobox_power)
        self.fan1_boost.sliderReleased.connect(self.slider_fan1)
        self.fan2_boost.sliderReleased.connect(self.slider_fan2)
        
        #Return
        groupBox.setLayout(vbox)
        return groupBox

    #Callbacks
    def combobox_choice(self):
        self.settings.setValue("Action", self.combobox_mode.currentText())


    def apply_leds(self):
        if not _awelc_usb_available():
            QMessageBox.information(
                self,
                "Keyboard LED",
                "No USB RGB keyboard (187c:0550/0551) was found.\n\n"
                "This section only works with the Alienware-style device; your doctor check already "
                "warned if 187c:0550 is missing. Power and fans (other tab) use ACPI, not the keyboard USB.",
            )
            return
        act = str(self.combobox_mode.currentText())
        try:
            if act == "Static Color":
                self.apply_static()
            elif act == "Morph":
                self.apply_morph()
            elif act == "Color and Morph":
                self.apply_color_and_morph()
            else:
                self.remove_animation()
        except Exception as err:
            QMessageBox.warning(
                self,
                "Error",
                "Cannot apply LED settings:\n\n{}: {}".format(err.__class__.__name__, err),
            )


    def combobox_power(self):
        self.fan1_boost.setValue(0)
        self.fan2_boost.setValue(0)
        self.settings.setValue("Power", self.combobox_mode_power.currentText())
        choice = self.settings.value("Power", "USTT_Balanced")
        message = ""
        
        # Set power mode
        mode = self.power_modes_dict[choice]
        self.acpi_call("set_power_mode",mode)
        # Get current power mode to confirm
        result = self.acpi_call("get_power_mode")
        if result is not None and _acpi_id_eq(result, mode):
            message = "Power mode set to {}.\n".format(choice)
        else:
            message = "Error! Command returned: {}, but expecting {}.\n".format(str(result), str(mode))
        # Get G Mode
        g = self.acpi_call("get_G_mode")
        want_g = choice == "G Mode"
        g_on = g is not None and _acpi_id_eq(g, "0x1")
        if want_g != g_on:
            result_toggle = self.acpi_call("toggle_G_mode")
            expect_t = "0x1" if want_g else "0x0"
            if result_toggle is None or not _acpi_id_eq(result_toggle, expect_t):
                message = message + "G Mode toggle: expected {} but got {} (get_G_mode was {}).\n".format(
                    expect_t, str(result_toggle), str(g)
                )

        self.info_label.setText(message)


    def slider_fan1(self):
        #Fan1 has id 0x32
        #Get current fan boost
        fan1_last_boost = self.acpi_call("get_fan1_boost")
        #Set new fan boost
        new_val = self.fan1_boost.value()
        self.acpi_call("set_fan1_boost","0x{:2X}".format(new_val))
        #Get current fan boost
        fan1_new_boost = self.acpi_call("get_fan1_boost")
        self.info_label.setText("Fan1 Boost: {:.0f}% to {:.0f}%.".format(_int_from_acpi(fan1_last_boost)/0xff*100,_int_from_acpi(fan1_new_boost)/0xff*100))


    def slider_fan2(self):
        #Fan2 has id 0x33
        #Get current fan boost
        fan2_last_boost = self.acpi_call("get_fan2_boost")
        #Set new fan boost
        new_val = self.fan2_boost.value()
        self.acpi_call("set_fan2_boost","0x{:2X}".format(new_val))
        #Get current fan boost
        fan2_new_boost = self.acpi_call("get_fan2_boost")
        self.info_label.setText("Fan2 Boost: {:.0f}% to {:.0f}%.".format(_int_from_acpi(fan2_last_boost)/0xff*100,_int_from_acpi(fan2_new_boost)/0xff*100))


    def get_rpm_and_temp(self):
        if self.isVisible():
            #Get current rpm and temp
            fan1_rpm = self.acpi_call("get_fan1_rpm")
            cpu_temp = self.acpi_call("get_cpu_temp")
            fan2_rpm = self.acpi_call("get_fan2_rpm")
            gpu_temp = self.acpi_call("get_gpu_temp")
            if None in (fan1_rpm, cpu_temp, fan2_rpm, gpu_temp):
                return
            self.fan1_current.setText("{} RPM, {} °C".format(_int_from_acpi(fan1_rpm),_int_from_acpi(cpu_temp)))
            self.fan2_current.setText("{} RPM, {} °C".format(_int_from_acpi(fan2_rpm),_int_from_acpi(gpu_temp)))
    # Helper Functions
    
    #Execute given command in elevated shell
    def acpi_call(self, cmd, arg1="0x00", arg2="0x00"):
        args = self.acpi_call_dict[cmd]
        if len(args)==4:
            cmd_current = self.acpi_cmd.format(args[0], args[1], args[2], args[3])
        elif len(args)==3:
            cmd_current = self.acpi_cmd.format(args[0], args[1], args[2], arg1)
        elif len(args)==2:
            cmd_current = self.acpi_cmd.format(args[0], args[1], arg1, arg2)
        else:
            cmd_current=""
        result = self.shell_exec(cmd_current)
        if len(result) < 2:
            return None
        out_lines = [ln for ln in result[1:] if ln.strip()]
        if not out_lines:
            return None
        for line in reversed(out_lines):
            parsed = _try_parse_acpi_line(line)
            if parsed is not None:
                return parsed
        return None


    def shell_exec(self, cmd : str):
        print("Bash: Executing {}".format(cmd))
        self.shell.sendline(cmd)
        self.shell.expect("[#$] ")
        result = self.shell.before
        result = result.split('\n')
        for line in result[1:]: #First line is the command that was sent
            print(line)
        return result


    def parse_shell_exec(self, line: str):
        return _try_parse_acpi_line(line)

    # Apply given colors to keyboard.
    def apply_static(self):
        awelc.set_static(self.red.value(), self.green.value(),
                         self.blue.value())
        self.settings.setValue("Action", "Static Color")
        self.settings.setValue("Red Static", self.red.value())
        self.settings.setValue("Green Static", self.green.value())
        self.settings.setValue("Blue Static", self.blue.value())
        self.settings.setValue("Duration", self.duration.value())
        self.settings.setValue("State", "On")


    def apply_morph(self):
        awelc.set_morph(self.red_morph.value(), self.green_morph.value(),
                        self.blue_morph.value(), self.duration.value())
        self.settings.setValue("Action", "Morph")
        self.settings.setValue("Red Morph", self.red_morph.value())
        self.settings.setValue("Green Morph", self.green_morph.value())
        self.settings.setValue("Blue Morph", self.blue_morph.value())
        self.settings.setValue("Duration", self.duration.value())
        self.settings.setValue("State", "On")


    def apply_color_and_morph(self):
        awelc.set_color_and_morph(self.red.value(), self.green.value(),
                        self.blue.value(), self.red_morph.value(), self.green_morph.value(),
                        self.blue_morph.value(), self.duration.value())
        self.settings.setValue("Action", "Color and Morph")
        self.settings.setValue("Red Static", self.red.value())
        self.settings.setValue("Green Static", self.green.value())
        self.settings.setValue("Blue Static", self.blue.value())
        self.settings.setValue("Red Morph", self.red_morph.value())
        self.settings.setValue("Green Morph", self.green_morph.value())
        self.settings.setValue("Blue Morph", self.blue_morph.value())
        self.settings.setValue("Duration", self.duration.value())
        self.settings.setValue("State", "On")


    def remove_animation(self):
        awelc.remove_animation()
        self.settings.setValue("State", "Off")

    # Apply last action when called from system tray
    def tray_on(self):
        # if self.settings.value("Action", "Static Color") == "Static Color":
        #     self.apply_static()
        # elif self.settings.value("Action", "Static Color") == "Morph":
        #     self.apply_morph()
        # else:  #Off
        #     self.remove_animation()
        awelc.set_dim(0)
        self.settings.setValue("State", "On")

    def tray_off(self):
        # awelc.set_static(0, 0, 0)
        # awelc.remove_animation()
        awelc.set_dim(100)
        self.settings.setValue("State", "Off")


class TrayIcon(QSystemTrayIcon):

    def __init__(self, window, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.settings = QSettings('Dell-G15', 'Controller')
        self.state = (self.settings.value("State", "Off"))
        self.activated.connect(self.toggle_leds)
        self.window = window

    def toggle_leds(self, reason):
        # Wayland: right-click opens the menu; do not also toggle
        if reason == QSystemTrayIcon.ActivationReason.Context:
            return
        if reason not in (
            QSystemTrayIcon.ActivationReason.Trigger,
            QSystemTrayIcon.ActivationReason.DoubleClick,
            QSystemTrayIcon.ActivationReason.MiddleClick,
        ):
            return
        if not _awelc_usb_available():
            QMessageBox.information(
                self.window,
                "Keyboard LED",
                "Tray dim/LED toggle needs the Alienware USB device (187c:0550/551).\n\n"
                "Without it, this click does nothing useful — use Power and Fans in the main window (ACPI).",
            )
            return
        try:
            if self.settings.value("State", "Off") == "Off":
                self.settings.setValue("State", "On")
                self.window.tray_on()
            else:
                self.settings.setValue("State", "Off")
                self.window.tray_off()
        except Exception as err:
            QMessageBox.warning(
                self.window,
                "Tray",
                "Keyboard LED error: {}: {}".format(err.__class__.__name__, err),
            )

if __name__ == '__main__':
    # Create the Qt Application
    app = QApplication(sys.argv)
    icon = _app_icon()
    app.setWindowIcon(icon)
    if icon.isNull():
        print("dell-g-controller: install an icon (window.png) for a visible tray; using fallback.", file=sys.stderr)
    app.setQuitOnLastWindowClosed(False)

    # Create and show the window
    window = MainWindow()
    window.show()

    # Add item on the system tray
    tray = TrayIcon(window)
    tray.setIcon(icon)
    tray.setVisible(True)
    tray.setToolTip("Dell G Series: left click toggles LED dim (needs 187c:0550); right = menu. Power/fans: open the window.")

    # System tray options
    menu = QMenu()
    show = QAction("Show Window")
    boost_on = QAction("Boost on")
    boost_off = QAction("Boost off")
    quit = QAction("Quit")
    menu.addAction(show)
    menu.addAction(quit)
    # Adding options to the System Tray
    tray.setContextMenu(menu)

    # Register callbacks
    quit.triggered.connect(app.quit)
    show.triggered.connect(window.show)

    # Run the main Qt loop
    sys.exit(app.exec())
