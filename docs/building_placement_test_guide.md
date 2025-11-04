# 🏗️ RTS Building Placement Test Guide

## ✅ **System Fixed!**

The building placement system has been completely rebuilt with proper RTS-style mechanics. Here's how to test it:

## 🎮 **How to Test Building Placement**

### **Step 1: Start the Game**
1. Run the SettlementBridge scene
2. You should see your settlement with existing buildings
3. Open the Storefront UI (should be visible by default)

### **Step 2: Purchase a Building**
1. Click on either:
   - **"Buy Wall"** button (costs wood + gold)
   - **"Buy Lumber Yard"** button (costs wood + gold)
2. Resources should be deducted from your treasury
3. **Building cursor should immediately activate**

### **Step 3: Place the Building**
1. **Move your mouse** - you should see:
   - A semi-transparent building sprite following your cursor
   - The sprite snaps to a grid
   - Color changes: 🟢 **Green** = valid placement, 🔴 **Red** = invalid
   - White outline showing the building's footprint

2. **Left-click** to place the building
   - Building should appear in the world
   - Cursor preview disappears
   - Settlement data is saved

3. **Right-click** to cancel placement
   - Cursor preview disappears
   - Resources are refunded to your treasury

## 🔧 **Expected Visual Feedback**

### **When Moving Cursor:**
- Building sprite follows mouse
- Snaps to 32x32 grid
- Green tint = can place here
- Red tint = invalid location (occupied or out of bounds)
- White outline shows exact building footprint

### **After Placement:**
- Building appears at the placed location
- Console shows: "Building placed successfully"
- Treasury updates are reflected in UI

### **After Cancellation:**
- Console shows: "Building placement cancelled by cursor"
- Resources refunded message appears
- Treasury values return to pre-purchase amounts

## 🐛 **Troubleshooting**

### **If cursor doesn't appear:**
1. Check console for error messages
2. Verify BuildingCursor node exists in scene
3. Make sure you have sufficient resources

### **If placement doesn't work:**
1. Try clicking in open areas (green zones)
2. Avoid red areas (existing buildings)
3. Check console for placement attempt messages

### **If visual feedback is missing:**
1. Look for BuildingPreviewCursor debug messages in console
2. Verify grid overlay is working
3. Check if building textures are loading

## 📝 **Console Messages to Look For**

**Successful Flow:**
```
Building ready for placement: Wall
Setting building preview for: Wall
BuildingPreviewCursor ready with cell_size: 32
Building placed successfully
Building placement completed successfully
```

**Cancelled Flow:**
```
Building placement cancelled by right click
Building placement cancelled by cursor, refunded: {gold: X, wood: Y}
```

## 🎯 **Advanced Testing**

1. **Test different building types** (Wall vs Lumber Yard)
2. **Test placement near existing buildings**
3. **Test rapid purchase/cancel cycles**
4. **Test placement at world edges**
5. **Verify settlement data persistence** (restart and check if buildings remain)

The new system provides classic RTS building placement with proper visual feedback, grid snapping, and validity checking! 🎮