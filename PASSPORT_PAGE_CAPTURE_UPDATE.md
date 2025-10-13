# Passport Page Capture - Updated Implementation

## Overview
Updated the passport capture system to focus on capturing the entire passport page (not just the photo) with proper 4.9" × 3.4" dimensions, exactly like the Eswatini passport example provided.

## Key Changes Made

### 1. **Terminology Updates**
- Changed from "Passport Photo" to "Passport Page" throughout the UI
- Updated all user-facing text to reflect capturing the entire page
- Clarified that users should photograph the complete passport page

### 2. **Dimension Specifications**
- Maintained exact 4.9" × 3.4" aspect ratio (≈ 1.44:1)
- Updated labels to show "Passport Page (4.9" × 3.4")"
- Emphasized standard passport page dimensions in UI

### 3. **User Instructions**
- **Before**: "Take a photo of your passport"
- **After**: "Capture your entire passport page (4.9" × 3.4")"
- Added guidance to include both photo and text information
- Updated crop instructions to position entire page within frame

### 4. **UI Text Updates**

#### Passport Image Widget
- Title: "Passport Page" (was "Passport Photo")
- Instructions: "Capture entire passport page with camera"
- Upload area: "Capture Passport Page" with "Standard page size: 4.9" × 3.4""
- Menu options: "Crop Page", "View Page", "Remove Page"

#### Crop Widget
- Title: "Crop Passport Page" 
- Instructions: "Position your passport page within the frame. Capture the entire page including photo and text."
- Frame label: "Passport Page (4.9" × 3.4")"

#### Profile Settings
- Section title: "Passport Page"
- Description: "Capture a clear photo of your entire passport page (4.9" × 3.4") for verification."

### 5. **Success/Error Messages**
- "Passport page uploaded successfully"
- "Passport page cropped and updated successfully"
- "Passport page removed successfully"
- Error messages updated accordingly

## Technical Specifications

### Passport Page Dimensions
- **Width**: 4.9 inches (125mm)
- **Height**: 3.4 inches (88mm)
- **Aspect Ratio**: 1.44:1
- **Content**: Full passport page including photo, text, and security features

### Cropping Area
- Uses 80% of screen width for crop frame
- Height calculated automatically from aspect ratio
- Visual guides show exact passport page proportions
- Corner indicators for precise positioning

### User Experience Flow
1. **Capture**: Take photo of entire passport page
2. **Crop**: Adjust positioning to fit standard dimensions
3. **Verify**: View captured page to ensure all information is visible
4. **Save**: Store properly formatted passport page image

## Benefits

### For Users
- **Clear Instructions**: Know exactly what to capture (entire page)
- **Proper Dimensions**: Ensures compliance with passport standards
- **Visual Guides**: Crop overlay shows exact passport proportions
- **Complete Capture**: Includes all passport information and security features

### For System
- **Standardized Format**: All passport images follow same dimensions
- **Better Recognition**: OCR and verification systems can process full page
- **Compliance**: Meets international passport documentation standards
- **Quality Control**: Cropping ensures consistent image quality

## Example Usage

Based on the Eswatini passport example:
- ✅ Captures entire page including header "Kingdom of Eswatini"
- ✅ Includes passport photo and all personal information
- ✅ Shows passport number, dates, and authority information
- ✅ Captures machine-readable zone at bottom
- ✅ Maintains proper 4.9" × 3.4" proportions

## Implementation Complete

The system now correctly captures passport pages rather than just photos, with:
- Proper terminology throughout the interface
- Clear instructions for full page capture
- Exact 4.9" × 3.4" dimension compliance
- Visual guides for optimal positioning
- Professional cropping interface

Users can now capture their complete passport pages exactly as shown in the Eswatini passport example, ensuring all information is properly documented for border crossing verification.