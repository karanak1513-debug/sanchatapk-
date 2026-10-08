import os
import hashlib
import zipfile

def verify_apk():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    apk_path = os.path.join(base_dir, "build", "app", "outputs", "flutter-apk", "app-release.apk")
    
    if not os.path.exists(apk_path):
        print(f"APK not found at {apk_path}")
        return None

    stat = os.stat(apk_path)
    size_mb = stat.st_size / (1024 * 1024)
    
    with open(apk_path, "rb") as f:
        bytes_data = f.read()
        sha256_hash = hashlib.sha256(bytes_data).hexdigest()
        sha1_hash = hashlib.sha1(bytes_data).hexdigest()
        md5_hash = hashlib.md5(bytes_data).hexdigest()

    print("==================================================")
    print("  SANCHAT RELEASE APK VERIFICATION REPORT")
    print("==================================================")
    print(f"Path: {apk_path}")
    print(f"File Size: {stat.st_size} bytes ({size_mb:.2f} MB)")
    print(f"SHA-256: {sha256_hash}")
    print(f"SHA-1:   {sha1_hash}")
    print(f"MD5:     {md5_hash}")

    # Inspect zip contents
    with zipfile.ZipFile(apk_path, 'r') as z:
        files = z.namelist()
        has_dex = any(f.endswith('.dex') for f in files)
        has_lib = any('lib/' in f for f in files)
        has_res = any('res/' in f for f in files)
        has_assets = any('assets/' in f for f in files)
        has_manifest = 'AndroidManifest.xml' in files
        
        print("\nAPK Structure Inspection:")
        print(f" - AndroidManifest.xml: {'PASS' if has_manifest else 'FAIL'}")
        print(f" - Classes DEX present: {'PASS' if has_dex else 'FAIL'}")
        print(f" - Native libraries (lib/): {'PASS' if has_lib else 'FAIL'}")
        print(f" - Resources present: {'PASS' if has_res else 'FAIL'}")
        print(f" - Asset bundle present: {'PASS' if has_assets else 'FAIL'}")
        print(f" - Total files bundled: {len(files)}")

    return {
        "path": apk_path,
        "size_bytes": stat.st_size,
        "size_mb": size_mb,
        "sha256": sha256_hash,
    }

if __name__ == "__main__":
    verify_apk()
