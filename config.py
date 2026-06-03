import os
import sys

def resource_path(relative_path):
    """ Get absolute path to resource, works for dev and for PyInstaller """
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")
    return os.path.join(base_path, relative_path)

# ==============================================================================
# GLOBAL SYSTEM BRANDING CONFIGURATION
# ==============================================================================
# Change these variables to customize the system branding globally across all
# windows, login screens, tabs, printed receipts, and exported PDFs.
# ==============================================================================

# 1. The display name of the store / system
SYSTEM_TITLE = "Archer POS"

# 2. The filename or absolute path of your custom logo image.
# Supported formats: PNG, JPG, JPEG, BMP (e.g., "archer_logo.png" or "my_logo.png")
SYSTEM_LOGO = "archer_logo.png"

# ==============================================================================
# UTILITY RESOLVERS (Used globally by the system)
# ==============================================================================
def get_system_title():
    return SYSTEM_TITLE

def get_system_logo():
    # If path is absolute, use it directly
    if os.path.isabs(SYSTEM_LOGO):
        if os.path.exists(SYSTEM_LOGO):
            return SYSTEM_LOGO
    
    # Try resolving relative path from executable base/MEIPASS
    resolved = resource_path(SYSTEM_LOGO)
    if os.path.exists(resolved):
        return resolved
        
    # Fallback to current working directory resolution
    fallback = os.path.abspath(SYSTEM_LOGO)
    if os.path.exists(fallback):
        return fallback
        
    # Final default fallback to default archer_logo.png if specified file does not exist
    default_logo = resource_path("archer_logo.png")
    return default_logo
