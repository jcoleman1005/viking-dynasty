# PROJECT API MAP
> **CONTEXT INSTRUCTION:** This file contains the STRUCTURE of the project. Implementation details are hidden to save space. Use this to understand available classes, functions, and signals.
> Generated: 2026-01-27T11:55:04

## 🏛️ GLOBAL ARCHITECTURE
### Autoloads (Singletons)
- **Loggie**: `res://addons/loggie/loggie.gd`
- **EventBus**: `res://autoload/EventBus.gd`
- **SettlementManager**: `res://autoload/SettlementManager.gd`
- **PauseManager**: `res://autoload/PauseManager.tscn`
- **WinterManager**: `res://autoload/WinterManager.tscn`
- **DynastyManager**: `res://autoload/DynastyManager.gd`
- **SceneManager**: `res://autoload/SceneManager.tscn`
- **EventManager**: `res://autoload/EventManager.tscn`
- **ProjectilePoolManager**: `res://autoload/ProjectilePoolManager.gd`
- **NavigationManager**: `res://autoload/NavigationManager.gd`
- **EconomyManager**: `res://autoload/EconomyManager.gd`
- **RaidManager**: `res://autoload/RaidManager.gd`

### Physics Layers
- Layer 1: Environment
- Layer 2: Player_Units
- Layer 3: Enemy_Units
- Layer 4: Enemy_Buildings

## 🎬 SCENE STRUCTURES

### `res:///KennyIsotowers.tscn`
- **TileMapLayer** [TileMapLayer]

### `res:///addons/GodotAiSuite/prompt_library/prompt_library.tscn`
- **PromptLibrary** [Window]
- **MarginContainer** [MarginContainer]
  - **HSplitContainer** [HSplitContainer]
    - **VBoxContainer** [VBoxContainer]
      - **SearchBar** [LineEdit]
      - **PromptTree** [Tree]
    - **VBoxContainer2** [VBoxContainer]
      - **TitleLabel** [Label]
      - **DescriptionLabel** [Label]
      - **HBoxContainer** [HBoxContainer]
        - **CopyButton** [Button]
        - **CopyFeedbackLabel** [Label]
      - **PromptText** [TextEdit]

### `res:///addons/gut/GutScene.tscn`
- **GutScene** [Node2D]
- **Normal** []
- **Compact** []

### `res:///addons/gut/UserFileViewer.tscn`
- **UserFileViewer** [Window]
- **FileDialog** [FileDialog]
- **TextDisplay** [ColorRect]
  - **RichTextLabel** [RichTextLabel]
- **OpenFile** [Button]
- **Home** [Button]
- **Copy** [Button]
- **End** [Button]
- **Close** [Button]
**Signals:**
- `FileDialog` -> `.` :: _on_FileDialog_file_selected()
- `FileDialog` -> `.` :: _on_file_dialog_visibility_changed()
- `OpenFile` -> `.` :: _on_OpenFile_pressed()
- `Home` -> `.` :: _on_Home_pressed()
- `Copy` -> `.` :: _on_Copy_pressed()
- `End` -> `.` :: _on_End_pressed()
- `Close` -> `.` :: _on_Close_pressed()

### `res:///addons/gut/gui/GutBottomPanel.tscn`
- **GutBottomPanel** [Control]
- **layout** [VBoxContainer]
  - **ControlBar** [HBoxContainer]
    - **RunAll** [Button]
    - **Sep3** [ColorRect]
    - **RunAtCursor** []
    - **CenterContainer2** [CenterContainer]
    - **MakeFloating** [Button]
  - **ControlBar2** [HBoxContainer]
    - **Sep2** [ColorRect]
    - **StatusIndicator** [Control]
    - **Passing** [HBoxContainer]
      - **Sep** [ColorRect]
      - **label** [Label]
      - **passing_value** [Label]
    - **Failing** [HBoxContainer]
      - **Sep** [ColorRect]
      - **label** [Label]
      - **failing_value** [Label]
    - **Pending** [HBoxContainer]
      - **Sep** [ColorRect]
      - **label** [Label]
      - **pending_value** [Label]
    - **Orphans** [HBoxContainer]
      - **Sep** [ColorRect]
      - **label** [Label]
      - **orphans_value** [Label]
    - **Errors** [HBoxContainer]
      - **Sep** [ColorRect]
      - **label** [Label]
      - **errors_value** [Label]
    - **Warnings** [HBoxContainer]
      - **Sep** [ColorRect]
      - **label** [Label]
      - **warnings_value** [Label]
    - **CenterContainer** [CenterContainer]
    - **ExtraButtons** [HBoxContainer]
      - **Sep1** [ColorRect]
      - **RunMode** [Button]
      - **Sep2** [ColorRect]
      - **RunResultsBtn** [Button]
      - **OutputBtn** [Button]
      - **Settings** [Button]
      - **Sep3** [ColorRect]
      - **Shortcuts** [Button]
      - **About** [Button]
  - **RSplit** [HSplitContainer]
    - **CResults** [VBoxContainer]
      - **HSplitResults** [HSplitContainer]
        - **RunResults** []
        - **OutputText** []
      - **VSplitResults** [VSplitContainer]
    - **sc** [ScrollContainer]
      - **Settings** [VBoxContainer]
- **ShortcutDialog** []
- **ShellOutOptions** []
**Signals:**
- `layout/ControlBar/RunAll` -> `.` :: _on_RunAll_pressed()
- `layout/ControlBar/RunAtCursor` -> `.` :: _on_RunAtCursor_run_tests()
- `layout/ControlBar/MakeFloating` -> `.` :: _on_to_window_pressed()
- `layout/ControlBar2/StatusIndicator` -> `.` :: _on_Light_draw()
- `layout/ControlBar2/ExtraButtons/RunMode` -> `.` :: _on_run_mode_pressed()
- `layout/ControlBar2/ExtraButtons/RunResultsBtn` -> `.` :: _on_RunResultsBtn_pressed()
- `layout/ControlBar2/ExtraButtons/OutputBtn` -> `.` :: _on_OutputBtn_pressed()
- `layout/ControlBar2/ExtraButtons/Settings` -> `.` :: _on_Settings_pressed()
- `layout/ControlBar2/ExtraButtons/Shortcuts` -> `.` :: _on_Shortcuts_pressed()
- `layout/ControlBar2/ExtraButtons/About` -> `.` :: _on_about_pressed()
- `ShortcutDialog` -> `.` :: _on_sortcut_dialog_confirmed()
- `ShellOutOptions` -> `.` :: _on_shell_out_options_confirmed()

### `res:///addons/gut/gui/GutControl.tscn`
- **GutControl** [Control]
- **Bg** [ColorRect]
- **VBox** [VBoxContainer]
  - **Tabs** [TabContainer]
    - **Tests** [Tree]
    - **SettingsScroll** [ScrollContainer]
      - **Settings** [VBoxContainer]
  - **Buttons** [HBoxContainer]
    - **RunTests** [Button]
    - **RunSelected** [Button]
**Signals:**
- `VBox/Tabs/Tests` -> `.` :: _on_tests_item_activated()
- `VBox/Buttons/RunTests` -> `.` :: _on_run_tests_pressed()
- `VBox/Buttons/RunSelected` -> `.` :: _on_run_selected_pressed()

### `res:///addons/gut/gui/GutEditorWindow.tscn`
- **GutEditorWindow** [Window]
- **ColorRect** [ColorRect]
- **Layout** [VBoxContainer]
  - **WinControls** [HBoxContainer]
    - **MenuBar** [MenuBar]
    - **CenterContainer** [CenterContainer]
    - **OnTop** [CheckButton]
    - **HorizLayout** [Button]
    - **VertLayout** [Button]
**Signals:**
- `.` -> `.` :: _on_close_requested()
- `.` -> `.` :: _on_size_changed()
- `Layout/WinControls/OnTop` -> `.` :: _on_on_top_toggled()
- `Layout/WinControls/HorizLayout` -> `.` :: _on_horiz_layout_pressed()
- `Layout/WinControls/VertLayout` -> `.` :: _on_vert_layout_pressed()

### `res:///addons/gut/gui/GutLogo.tscn`
- **Logo** [Node2D]
- **BaseLogo** [Sprite2D]
  - **LeftEye** [Sprite2D]
  - **RightEye** [Sprite2D]
- **ResetTimer** [Timer]
- **FaceButton** [Button]
**Signals:**
- `ResetTimer` -> `.` :: _on_reset_timer_timeout()
- `FaceButton` -> `.` :: _on_face_button_pressed()

### `res:///addons/gut/gui/GutRunner.tscn`
- **GutRunner** [Node2D]
- **GutLayer** [CanvasLayer]
  - **GutScene** []

### `res:///addons/gut/gui/MinGui.tscn`
- **Min** [Panel]
- **MainBox** [VBoxContainer]
  - **TitleBar** [Panel]
    - **TitleBox** [HBoxContainer]
      - **Spacer1** [CenterContainer]
      - **Title** [Label]
      - **Spacer2** [CenterContainer]
      - **TimeLabel** [Label]
  - **Body** [HBoxContainer]
    - **LeftMargin** [CenterContainer]
    - **BodyRows** [VBoxContainer]
      - **ProgressBars** [HBoxContainer]
        - **HBoxContainer** [HBoxContainer]
          - **Label** [Label]
          - **ProgressTest** [ProgressBar]
        - **HBoxContainer2** [HBoxContainer]
          - **Label** [Label]
          - **ProgressScript** [ProgressBar]
      - **PathDisplay** [VBoxContainer]
        - **Path** [Label]
        - **HBoxContainer** [HBoxContainer]
          - **S3** [CenterContainer]
          - **File** [Label]
      - **Footer** [HBoxContainer]
        - **HandleLeft** []
        - **SwitchModes** [Button]
        - **CenterContainer** [CenterContainer]
        - **Continue** [Button]
        - **HandleRight** []
    - **RightMargin** [CenterContainer]
  - **CenterContainer** [CenterContainer]

### `res:///addons/gut/gui/NormalGui.tscn`
- **Large** [Panel]
- **MainBox** [VBoxContainer]
  - **TitleBar** [Panel]
    - **TitleBox** [HBoxContainer]
      - **Spacer1** [CenterContainer]
      - **Title** [Label]
      - **Spacer2** [CenterContainer]
      - **TimeLabel** [Label]
  - **HBoxContainer** [HBoxContainer]
    - **VBoxContainer** [VBoxContainer]
      - **OutputBG** [ColorRect]
        - **HBoxContainer** [HBoxContainer]
          - **S2** [CenterContainer]
          - **TestOutput** [RichTextLabel]
          - **S1** [CenterContainer]
      - **ControlBox** [HBoxContainer]
        - **S1** [CenterContainer]
        - **ProgressBars** [VBoxContainer]
          - **TestBox** [HBoxContainer]
            - **Label** [Label]
            - **ProgressTest** [ProgressBar]
          - **ScriptBox** [HBoxContainer]
            - **Label** [Label]
            - **ProgressScript** [ProgressBar]
        - **PathDisplay** [VBoxContainer]
          - **Path** [Label]
          - **HBoxContainer** [HBoxContainer]
            - **S3** [CenterContainer]
            - **File** [Label]
        - **Buttons** [VBoxContainer]
          - **Continue** [Button]
          - **WordWrap** [CheckButton]
        - **S3** [CenterContainer]
  - **BottomPad** [CenterContainer]
  - **Footer** [HBoxContainer]
    - **SidePad1** [CenterContainer]
    - **ResizeHandle3** []
    - **SwitchModes** [Button]
    - **CenterContainer** [CenterContainer]
    - **ResizeHandle2** []
    - **SidePad2** [CenterContainer]
  - **BottomPad2** [CenterContainer]

### `res:///addons/gut/gui/OutputText.tscn`
- **OutputText** [VBoxContainer]
- **Toolbar** [HBoxContainer]
  - **ShowSearch** [Button]
  - **ShowSettings** [Button]
  - **CenterContainer** [CenterContainer]
  - **LblPosition** [Label]
  - **CopyButton** [Button]
  - **ClearButton** [Button]
- **Settings** [HBoxContainer]
  - **WordWrap** [Button]
  - **UseColors** [Button]
- **Output** [TextEdit]
- **Search** [HBoxContainer]
  - **SearchTerm** [LineEdit]
  - **SearchNext** [Button]
  - **SearchPrev** [Button]
**Signals:**
- `Toolbar/ShowSearch` -> `.` :: _on_ShowSearch_pressed()
- `Toolbar/ShowSettings` -> `.` :: _on_settings_pressed()
- `Toolbar/CopyButton` -> `.` :: _on_CopyButton_pressed()
- `Toolbar/ClearButton` -> `.` :: _on_ClearButton_pressed()
- `Settings/WordWrap` -> `.` :: _on_WordWrap_pressed()
- `Settings/UseColors` -> `.` :: _on_UseColors_pressed()
- `Search/SearchTerm` -> `.` :: _on_SearchTerm_focus_entered()
- `Search/SearchTerm` -> `.` :: _on_SearchTerm_gui_input()
- `Search/SearchTerm` -> `.` :: _on_SearchTerm_text_changed()
- `Search/SearchTerm` -> `.` :: _on_SearchTerm_text_entered()
- `Search/SearchNext` -> `.` :: _on_SearchNext_pressed()
- `Search/SearchPrev` -> `.` :: _on_SearchPrev_pressed()

### `res:///addons/gut/gui/ResizeHandle.tscn`
- **ResizeHandle** [ColorRect]

### `res:///addons/gut/gui/ResultsTree.tscn`
- **ResultsTree** [VBoxContainer]
- **TextOverlay** [Label]

### `res:///addons/gut/gui/RunAtCursor.tscn`
- **RunAtCursor** [Control]
- **HBox** [HBoxContainer]
  - **LblNoneSelected** [Label]
  - **BtnRunScript** [Button]
  - **Arrow1** [TextureButton]
  - **BtnRunInnerClass** [Button]
  - **Arrow2** [TextureButton]
  - **BtnRunMethod** [Button]
**Signals:**
- `HBox/BtnRunScript` -> `.` :: _on_BtnRunScript_pressed()
- `HBox/BtnRunInnerClass` -> `.` :: _on_BtnRunInnerClass_pressed()
- `HBox/BtnRunMethod` -> `.` :: _on_BtnRunMethod_pressed()

### `res:///addons/gut/gui/RunExternally.tscn`
- **DoShellOut** [Control]
- **BgControl** [Panel]
  - **VBox** [VBoxContainer]
    - **Spacer** [CenterContainer]
    - **Title** [Label]
    - **Spacer2** [CenterContainer]
    - **Kill** [Button]
    - **Spacer3** [CenterContainer]
**Signals:**
- `BgControl` -> `.` :: _on_color_rect_gui_input()
- `BgControl/VBox/Kill` -> `.` :: _on_kill_pressed()

### `res:///addons/gut/gui/RunResults.tscn`
- **RunResults** [Control]
- **VBox** [VBoxContainer]
  - **Toolbar** [HBoxContainer]
    - **Expand** [Button]
    - **Collapse** [Button]
    - **Sep** [ColorRect]
    - **LblAll** [Label]
    - **ExpandAll** [Button]
    - **CollapseAll** [Button]
    - **Sep2** [ColorRect]
    - **HidePassing** [CheckBox]
    - **Sep3** [ColorRect]
    - **LblSync** [Label]
    - **ShowScript** [Button]
    - **ScrollOutput** [Button]
  - **Output** [Panel]
    - **Scroll** [ScrollContainer]
      - **Tree** []
- **FontSampler** [Label]
**Signals:**
- `VBox/Toolbar/Expand` -> `.` :: _on_Expand_pressed()
- `VBox/Toolbar/Collapse` -> `.` :: _on_Collapse_pressed()
- `VBox/Toolbar/ExpandAll` -> `.` :: _on_ExpandAll_pressed()
- `VBox/Toolbar/CollapseAll` -> `.` :: _on_CollapseAll_pressed()
- `VBox/Toolbar/HidePassing` -> `.` :: _on_Hide_Passing_pressed()

### `res:///addons/gut/gui/Settings.tscn`
- **Settings** [VBoxContainer]

### `res:///addons/gut/gui/ShellOutOptions.tscn`
- **ShellOutOptions** [ConfirmationDialog]
- **ScrollContainer** [ScrollContainer]
  - **VBoxContainer** [VBoxContainer]
- **AcceptDialog** [AcceptDialog]

### `res:///addons/gut/gui/ShortcutButton.tscn`
- **ShortcutButton** [Control]
- **Layout** [HBoxContainer]
  - **lblShortcut** [Label]
  - **CenterContainer** [CenterContainer]
  - **SetButton** [Button]
  - **SaveButton** [Button]
  - **CancelButton** [Button]
  - **ClearButton** [Button]
**Signals:**
- `Layout/SetButton` -> `.` :: _on_SetButton_pressed()
- `Layout/SaveButton` -> `.` :: _on_SaveButton_pressed()
- `Layout/CancelButton` -> `.` :: _on_CancelButton_pressed()
- `Layout/ClearButton` -> `.` :: _on_ClearButton_pressed()

### `res:///addons/gut/gui/ShortcutDialog.tscn`
- **ShortcutDialog** [ConfirmationDialog]
- **Scroll** [ScrollContainer]
  - **Layout** [VBoxContainer]
    - **ShortcutDescription** [RichTextLabel]
    - **TopPad** [CenterContainer]
    - **CPanelButton** [HBoxContainer]
      - **Label** [Label]
      - **ShortcutButton** []
    - **ShortcutDescription2** [RichTextLabel]
    - **CRunAll** [HBoxContainer]
      - **Label** [Label]
      - **ShortcutButton** []
    - **ShortcutDescription3** [RichTextLabel]
    - **CRunCurrentScript** [HBoxContainer]
      - **Label** [Label]
      - **ShortcutButton** []
    - **ShortcutDescription4** [RichTextLabel]
    - **CRunCurrentInner** [HBoxContainer]
      - **Label** [Label]
      - **ShortcutButton** []
    - **ShortcutDescription5** [RichTextLabel]
    - **CRunCurrentTest** [HBoxContainer]
      - **Label** [Label]
      - **ShortcutButton** []
    - **ShortcutDescription6** [RichTextLabel]
    - **CRunAtCursor** [HBoxContainer]
      - **Label** [Label]
      - **ShortcutButton** []
    - **ShortcutDescription7** [RichTextLabel]
    - **CRerun** [HBoxContainer]
      - **Label** [Label]
      - **ShortcutButton** []
    - **ShortcutDescription8** [RichTextLabel]
    - **CToggleWindowed** [HBoxContainer]
      - **Label** [Label]
      - **ShortcutButton** []
    - **ShortcutDescription9** [RichTextLabel]

### `res:///addons/gut/gui/about.tscn`
- **About** [AcceptDialog]
- **HBox** [HBoxContainer]
  - **MakeRoomForLogo** [CenterContainer]
  - **Scroll** [ScrollContainer]
    - **RichTextLabel** [RichTextLabel]
- **Logo** []
**Signals:**
- `.` -> `.` :: _on_mouse_entered()
- `.` -> `.` :: _on_mouse_exited()
- `HBox/Scroll/RichTextLabel` -> `.` :: _on_rich_text_label_meta_clicked()
- `HBox/Scroll/RichTextLabel` -> `.` :: _on_rich_text_label_meta_hover_ended()
- `HBox/Scroll/RichTextLabel` -> `.` :: _on_rich_text_label_meta_hover_started()
- `Logo` -> `.` :: _on_logo_pressed()

### `res:///addons/gut/gui/run_from_editor.tscn`
- **RunFromEditor** [Node2D]

### `res:///addons/gut/gut_loader_the_scene.tscn`
- **Node** [Node2D]

### `res:///addons/loggie/version_management/update_prompt_window.tscn`
- **UpdatePromptWindow** [Panel]
- **Notice** [Control]
  - **Background** [TextureRect]
  - **LabelLatestVersion** [Label]
  - **LabelCurrentVersion** [Label]
  - **VBoxContainer** [VBoxContainer]
    - **Label** [Label]
    - **HBoxContainer** [HBoxContainer]
      - **NoticeButtons** [HBoxContainer]
        - **ReleaseNotesBtn** [Button]
        - **UpdateNowBtn** [Button]
        - **RemindLaterBtn** [Button]
  - **DontShowAgainCheckbox** [CheckBox]
- **UpdateMonitor** [Control]
  - **BackgroundUnder** [TextureRect]
  - **BackgroundOver** [TextureRect]
  - **ProgressBar** [ProgressBar]
  - **LabelMainStatus** [Label]
  - **LabelOldVersion** [Label]
  - **LabelNewVersion** [Label]
  - **LoggieIcon** [TextureRect]
  - **VBoxContainer** [VBoxContainer]
    - **OptionButtons** [HBoxContainer]
      - **OptionRetryUpdateBtn** [Button]
      - **OptionRestartGodotBtn** [Button]
      - **OptionExitBtn** [Button]
    - **LabelUpdateStatus** [Label]
- **AnimationPlayer** [AnimationPlayer]

### `res:///autoload/EventManager.tscn`
- **EventManager** [Node]

### `res:///autoload/PauseManager.tscn`
- **PauseManager** [Node]

### `res:///autoload/SceneManager.tscn`
- **SceneManager** [Node]

### `res:///autoload/WinterManager.tscn`
- **WinterManager** [Node]

### `res:///data/resources/SpringCouncilUI.tscn`
- **SpringCouncil_UI** [Control]
- **Background** [ColorRect]
- **Title** [Label]
- **CardContainer** [HBoxContainer]
- **ConfirmPanel** [Control]
  - **ConfirmLabel** [Label]
  - **CommitButton** [Button]

### `res:///player/RTSController.tscn`
- **RTSController** [Node]

### `res:///player/RTSInputHandler.tscn`
- **RtsInputHandler** [Node]

### `res:///scenes/LevelDesignTemplate.tscn`
- **LevelDesignTemplate** [Node2D]
- **LevelDesignerTools** [Node2D]
  - **GridVisualizer** [Node2D]
    - **ReferenceRect** [ReferenceRect]
  - **Instructions (Won\'t be in final scene)** [Label]
  - **_Palette** [Node2D]
    - **Civilian** [Node2D]
      - **GreatHall_ref** [StaticBody2D]
      - **Lumber_ref** [StaticBody2D]
      - **Farm_ref** [StaticBody2D]
      - **Chapel_ref** [StaticBody2D]
    - **Military** [Node2D]
      - **Watchtower_ref** [StaticBody2D]
    - **Walls** [Node2D]
      - **Wall_ref** [StaticBody2D]
- **TileMapLayer** [TileMapLayer]
- **BuildingContainer** [Node2D]

### `res:///scenes/buildings/Base_Building.tscn`
- **Base_Building** [StaticBody2D]

### `res:///scenes/components/AttackAI.tscn`
- **AttackAI** [Node2D]
- **DetectionArea** [Area2D]
  - **CollisionShape2D** [CollisionShape2D]
- **AttackTimer** [Timer]

### `res:///scenes/effects/Projectile.tscn`
- **Projectile** [Area2D]
- **Sprite2D** [Sprite2D]
- **CollisionShape2D** [CollisionShape2D]
- **LifetimeTimer** [Timer]

### `res:///scenes/levels/DefensiveMicro.tscn`
- **DefensiveMicro** [Node2D]
- **TileMap** [TileMap]
- **PlayerStartPosition** [Marker2D]
- **RTSController** []
- **RTSCamera** [Camera2D]
- **BuildingContainer** [Node2D]
- **RaidObjectiveManager** [Node]
- **EnemySpawnPosition** [Marker2D]

### `res:///scenes/levels/SettlementBridge.tscn`
- **SettlementBridge** [Node2D]
- **TileMapLayer** [TileMapLayer]
- **UnitContainer** [Node2D]
- **UI** [CanvasLayer]
  - **SelectionBox** []
  - **Storefront_UI** []
  - **Dynasty_UI** []
  - **EndOfYear_Popup** []
  - **RestartButton** [Button]
  - **PauseButton** [Button]
  - **BuildingInspector** []
  - **SpringCouncil_UI** []
  - **SummerRaid_UI** []
- **BuildingCursor** [Node2D]
- **BuildingContainer** [Node2D]
- **GridVisualizer** []
- **Camera2D** [Camera2D]
- **MapResources** [Node2D]
  - **Resource_Wood** []
    - **Sprite2D** []
  - **Resource_Food** []
    - **Sprite2D** []
- **RTSController** []
- **RtsInputHandler** []
- **UnitSpawner** []
- **DebugNav** [Node2D]
- **TempDebugNode** [Node2D]

### `res:///scenes/missions/RaidMission.tscn`
- **RaidMission** [Node2D]
- **TileMapLayer** [TileMapLayer]
- **PlayerStartPosition** [Marker2D]
- **EnemySpawnPosition** [Marker2D]
- **RTSController** []
- **RTSInputHandler** [Node]
- **CanvasLayer** [CanvasLayer]
  - **SelectionBox** []
- **RTSCamera** [Camera2D]
- **GridVisualizer** []
- **BuildingContainer** [Node2D]
- **RaidObjectiveManager** [Node]
- **UnitSpawner** []

### `res:///scenes/units/Base_Unit.tscn`
- **Base_Unit** [CharacterBody2D]
- **Sprite2D** [Sprite2D]
- **CollisionShape2D** [CollisionShape2D]
- **AttackTimer** [Timer]
- **SeparationArea** [Area2D]
  - **CollisionShape2D** [CollisionShape2D]
- **StuckDetector** [Node]

### `res:///scenes/units/Bondi.tscn`
- **PlayerVikingRaider** [CharacterBody2D]
- **Sprite2D** [Sprite2D]
- **CollisionShape2D** [CollisionShape2D]
- **AttackTimer** [Timer]
- **SeparationArea** [Area2D]
  - **CollisionShape2D** [CollisionShape2D]

### `res:///scenes/units/BondiUnit.tscn`
- **Main** [Node2D]

### `res:///scenes/units/Civilian.tscn`
- **Civilian** []
- **Sprite2D** []

### `res:///scenes/units/Drengr.tscn`
- **Drengr** [CharacterBody2D]
- **Sprite2D** [Sprite2D]
- **CollisionShape2D** [CollisionShape2D]
- **AttackTimer** [Timer]
- **SeparationArea** [Area2D]
  - **CollisionShape2D** [CollisionShape2D]

### `res:///scenes/units/EnemyVikingRaider(depreciated).tscn`
- **EnemyVikingRaider** []
- **Sprite2D** []

### `res:///scenes/units/PlayerVikingRaider.tscn`
- **PlayerVikingRaider** []
- **Sprite2D** []

### `res:///scenes/units/Thrall.tscn`
- **Thrall** []

### `res:///scenes/units/VikingRaider.tscn`
- **VikingRaider** []
- **Sprite2D** []
- **CollisionShape2D** []

### `res:///scenes/world/Resource_Wood.tscn`
- **Resource_Wood** [Area2D]
- **Sprite2D** [Sprite2D]
- **CollisionShape2D** [CollisionShape2D]

### `res:///scenes/world/UnitSpawner.tscn`
- **UnitSpawner** [Node]

### `res:///scenes/world_map/MacroCamera.tscn`
- **MacroCamera** [Camera2D]

### `res:///scenes/world_map/MacroMap.tscn`
- **MacroMap** [Node2D]
- **TextureRect** [TextureRect]
- **Regions** [Node2D]
  - **Region_Southern_Sweden** []
    - **HighlightPoly** []
    - **CollisionPolygon2D** []
  - **Region_Southern_Norway** []
    - **HighlightPoly** []
  - **Region_Northern_Sweden** []
    - **HighlightPoly** []
  - **Region_Northern_Norway** []
    - **HighlightPoly** []
  - **Region_Denmark** []
    - **HighlightPoly** []
  - **Region_Finland** []
    - **HighlightPoly** []
  - **Region_Estonia** []
    - **HighlightPoly** []
  - **Region_Northern_Baltics** []
    - **HighlightPoly** []
  - **Region_Southern_Baltics** []
    - **HighlightPoly** []
  - **Region_10** []
    - **HighlightPoly** []
  - **Region_Germany_East** []
    - **HighlightPoly** []
  - **Region_Francia** []
    - **HighlightPoly** []
  - **Region_Germany_West** []
    - **HighlightPoly** []
  - **Region_Brittain** []
    - **HighlightPoly** []
- **MacroCamera** []
- **UI** [CanvasLayer]
  - **JarlInfo** [PanelContainer]
    - **VBoxContainer** [VBoxContainer]
      - **AuthorityLabel** [Label]
      - **RenownLabel** [Label]
  - **Actions** [PanelContainer]
    - **VBoxContainer** [VBoxContainer]
      - **SettlementButton** [Button]
      - **DynastyButton** [Button]
  - **RegionInfo** [PanelContainer]
    - **VBoxContainer** [VBoxContainer]
      - **RegionNameLabel** [Label]
      - **TargetList** [VBoxContainer]
      - **LaunchRaidButton** [Button]
      - **SubjugateButton** [Button]
      - **MarryButton** [Button]
  - **Tooltip** [PanelContainer]
    - **Label** [Label]
  - **Dynasty_UI** []
- **PlayerHomeMarker** [Marker2D]

### `res:///scenes/world_map/Region.tscn`
- **Region** [Area2D]
- **HighlightPoly** [Polygon2D]
- **CollisionPolygon2D** [CollisionPolygon2D]

### `res:///scripts/ui/PauseMenu.tscn`
- **PauseMenu** [CanvasLayer]
- **PanelContainer** [PanelContainer]
  - **MainMenuContainer** [VBoxContainer]
    - **ResumeButton** [Button]
    - **SaveButton** [Button]
    - **NewGameButton** [Button]
    - **DebugButton** [Button]
    - **QuitButton** [Button]
  - **DebugMenuContainer** [VBoxContainer]
    - **Btn_AddGold** [Button]
    - **Btn_AddRenown** [Button]
    - **Btn_UnlockLegacy** [Button]
    - **Btn_TriggerRaid** [Button]
    - **Btn_KillJarl** [Button]
    - **Btn_Back** [Button]

### `res:///scripts/utility/GridVisualizer.tscn`
- **GridVisualizer** [Node2D]
- **UnitPathDrawer** [Node2D]

### `res:///test/fixtures/SmokeTest.tscn`
- **SmokeTest** [Node2D]
- **CanvasLayer** [CanvasLayer]

### `res:///test/test_year_cycle_scene.tscn`
- **Main** [Node]
- **TestRunner** [Node]

### `res:///ui/BuildingPreviewCursor.tscn`
- **BuildingPreviewCursor** [Node2D]

### `res:///ui/Dynasty_UI.tscn`
- **Dynasty_UI** [PanelContainer]
- **Margin** [MarginContainer]
  - **MainLayout** [VBoxContainer]
    - **AncestorsScroll** [ScrollContainer]
      - **AncestorsHBox** [HBoxContainer]
    - **HSeparator** [HSeparator]
    - **CurrentJarlPanel** [HBoxContainer]
      - **Portrait** [TextureRect]
      - **Stats** [VBoxContainer]
        - **NameLabel** [Label]
        - **StatsLabel** [Label]
    - **HSeparator2** [HSeparator]
    - **HeirsLabel** [Label]
    - **HeirsScroll** [ScrollContainer]
      - **HeirsHBox** [HBoxContainer]
    - **CloseButton** [Button]
- **ContextMenu** [PopupMenu]

### `res:///ui/EndOfYear_Popup.tscn`
- **EndOfYear_Popup** [PanelContainer]
- **MarginContainer** [MarginContainer]
  - **VBoxContainer** [VBoxContainer]
    - **PayoutLabel** [RichTextLabel]
    - **LootDistributionPanel** [PanelContainer]
      - **@VBoxContainer@30028** [VBoxContainer]
        - **@Label@30029** [Label]
        - **@HBoxContainer@30030** [HBoxContainer]
          - **@Label@30031** [Label]
          - **LootSlider** [HSlider]
          - **@Label@30032** [Label]
        - **DistributionResultLabel** [Label]
    - **CollectButton** [Button]

### `res:///ui/Event_UI.tscn`
- **Event_UI** [CanvasLayer]
- **PanelContainer** [PanelContainer]
  - **Margin** [MarginContainer]
    - **VBox** [VBoxContainer]
      - **TitleLabel** [Label]
      - **HSeparator** [HSeparator]
      - **HBox** [HBoxContainer]
        - **Portrait** [TextureRect]
        - **DescriptionLabel** [Label]
      - **HSeparator2** [HSeparator]
      - **ChoiceButtonsContainer** [VBoxContainer]

### `res:///ui/RaidPrepWindow.tscn`
- **RaidPrepWindow** [PanelContainer]
- **MarginContainer** [MarginContainer]
  - **MainVBox** [VBoxContainer]
    - **HeaderLabel** [Label]
    - **HSeparator** [HSeparator]
    - **ContentHBox** [HBoxContainer]
      - **LeftCol** [VBoxContainer]
        - **TargetNameLabel** [Label]
        - **DescriptionLabel** [RichTextLabel]
        - **StatsGrid** [GridContainer]
          - **LabelDiff** [Label]
          - **ValDiff** [Label]
          - **LabelCost** [Label]
          - **ValCost** [Label]
          - **LabelTravel** [Label]
          - **ValTravel** [Label]
      - **VSeparator** [VSeparator]
      - **RightCol** [VBoxContainer]
        - **CapacityLabel** [Label]
        - **ScrollContainer** [ScrollContainer]
          - **WarbandList** [VBoxContainer]
        - **BondiPanel** [PanelContainer]
          - **BondiVBox** [VBoxContainer]
            - **BondiLabel** [Label]
            - **BondiSliderBox** [HBoxContainer]
              - **BondiSlider** [HSlider]
              - **BondiCountLabel** [Label]
    - **HSeparator2** [HSeparator]
    - **ProvisionsPanel** [PanelContainer]
      - **HBox** [HBoxContainer]
        - **Label** [Label]
        - **ProvisionSlider** [HSlider]
        - **CostLabel** [Label]
        - **EffectLabel** [Label]
    - **ActionButtons** [HBoxContainer]
      - **CancelButton** [Button]
      - **LaunchButton** [Button]

### `res:///ui/SelectionBox.tscn`
- **SelectionBox** [Control]

### `res:///ui/Storefront_UI.tscn`
- **Storefront_UI** [Control]
- **TreasuryHUD** []
- **Windows** [Control]
  - **BuildWindow** [PanelContainer]
    - **MarginContainer** [MarginContainer]
      - **ScrollContainer** [ScrollContainer]
        - **BuildGrid** [GridContainer]
  - **RecruitWindow** [PanelContainer]
    - **MarginContainer** [MarginContainer]
      - **ScrollContainer** [ScrollContainer]
        - **RecruitList** [VBoxContainer]
  - **LegacyWindow** [PanelContainer]
    - **MarginContainer** [MarginContainer]
      - **VBoxContainer** [VBoxContainer]
        - **JarlStats** [HBoxContainer]
          - **RenownLabel** [Label]
          - **AuthorityLabel** [Label]
        - **HSeparator** [HSeparator]
        - **ScrollContainer** [ScrollContainer]
          - **LegacyList** [VBoxContainer]
- **BottomDeck** [PanelContainer]
  - **HBoxContainer** [HBoxContainer]
    - **Btn_Build** [Button]
    - **Btn_Allocation** [Button]
    - **Btn_Recruit** [Button]
    - **Btn_LegacyUpgrades** [Button]
    - **Btn_Family** [Button]
    - **VSeparator** [VSeparator]
    - **Btn_Map** [Button]
    - **Btn_EndYear** [Button]
    - **DateLabel** [Label]

### `res:///ui/Succession_Crisis_UI.tscn`
- **Succession_Crisis_UI** [CanvasLayer]
- **PanelContainer** [PanelContainer]
  - **MarginContainer** [MarginContainer]
    - **VBoxContainer** [VBoxContainer]
      - **TitleLabel** [Label]
      - **DescriptionLabel** [Label]
      - **LegitimacyLabel** [Label]
      - **HSeparator** [HSeparator]
      - **RenownTaxTitle** [Label]
      - **RenownTaxDescription** [Label]
      - **RenownTaxButtons** [HBoxContainer]
        - **PayRenownButton** [Button]
        - **RefuseRenownButton** [Button]
      - **HSeparator2** [HSeparator]
      - **GoldTaxTitle** [Label]
      - **GoldTaxDescription** [Label]
      - **GoldTaxButtons** [HBoxContainer]
        - **PayGoldButton** [Button]
        - **RefuseGoldButton** [Button]
      - **HSeparator3** [HSeparator]
      - **ConfirmButton** [Button]

### `res:///ui/WinterCourtUi_depreciated.tscn`
- **WinterCourt_UI** [Control]
- **Background** [TextureRect]
- **MarginContainer** [MarginContainer]
  - **ScreenMargin** [MarginContainer]
    - **RootLayout** [VBoxContainer]
      - **TopLayout** [HBoxContainer]
        - **LeftPanel** [PanelContainer]
          - **VBoxContainer** [VBoxContainer]
            - **ActionPointsLabel** [Label]
            - **JarlNameLabel** [Label]
            - **JarlPortrait** [TextureRect]
        - **CenterPanel** [VBoxContainer]
          - **Btn_Feast** [Button]
          - **Btn_Thing** [Button]
          - **Btn_Blot** [Button]
          - **Btn_Heir** [Button]
          - **Btn_Refit** [Button]
        - **RightPanel** [PanelContainer]
          - **VBoxContainer** [VBoxContainer]
            - **UpkeepLabel** [RichTextLabel]
            - **FleetLabel** [Label]
            - **UnrestLabel** [Label]
      - **BottomPanel** [HBoxContainer]
        - **Btn_EndWinter** [Button]
- **DisputeOverlay** [PanelContainer]
  - **MarginContainer** [MarginContainer]
    - **VBoxContainer** [VBoxContainer]
      - **TitleLabel** [Label]
      - **DescriptionLabel** [Label]
      - **HBoxContainer** [HBoxContainer]
        - **Btn_Gold** [Button]
        - **Btn_Force** [Button]
        - **Btn_Ignore** [Button]

### `res:///ui/WinterCourt_UI.tscn`
- **WinterCourt_UI** [Control]
- **Background** [TextureRect]
- **TreasuryHUD** []
- **MarginContainer** [MarginContainer]
  - **ScreenMargin** [MarginContainer]
    - **RootLayout** [VBoxContainer]
      - **TreasuryHeader** [HBoxContainer]
      - **TopLayout** [HBoxContainer]
        - **LeftPanel** [PanelContainer]
          - **VBoxContainer** [VBoxContainer]
            - **ActionPointsLabel** [Label]
            - **JarlNameLabel** [Label]
            - **JarlPortrait** [TextureRect]
        - **CenterPanel** [VBoxContainer]
          - **Btn_Feast** [Button]
          - **Btn_Thing** [Button]
          - **Btn_Blot** [Button]
          - **Btn_Heir** [Button]
          - **Btn_Refit** [Button]
        - **RightPanel** [PanelContainer]
          - **VBoxContainer** [VBoxContainer]
            - **UpkeepLabel** [RichTextLabel]
            - **FleetLabel** [Label]
            - **UnrestLabel** [Label]
      - **BottomPanel** [HBoxContainer]
        - **Btn_EndWinter** [Button]
- **DisputeOverlay** [PanelContainer]
  - **MarginContainer** [MarginContainer]
    - **VBoxContainer** [VBoxContainer]
      - **TitleLabel** [RichTextLabel]
      - **DescriptionLabel** [RichTextLabel]
      - **HBoxContainer** [HBoxContainer]
        - **Btn_Gold** [Button]
        - **Btn_Force** [Button]
        - **Btn_Ignore** [Button]

### `res:///ui/WorkAssignment_UI.tscn`
- **WorkAssignment_UI** [CanvasLayer]
- **PanelContainer** [PanelContainer]
  - **MarginContainer** [MarginContainer]
    - **VBoxContainer** [VBoxContainer]
      - **Header** [HBoxContainer]
        - **TotalPopLabel** [Label]
        - **AvailablePopLabel** [Label]
      - **HSeparator** [HSeparator]
      - **SlidersContainer** [VBoxContainer]
      - **HSeparator2** [HSeparator]
      - **ConfirmButton** [Button]

### `res:///ui/components/BuildingInfoHud.tscn`
- **BuildingInfoHUD** [Control]
- **Background** [PanelContainer]
  - **MarginContainer** [MarginContainer]
    - **NameLabel** [Label]
- **HealthBar** [ProgressBar]
- **StatusIcon** [TextureRect]

### `res:///ui/components/BuildingInspector.tscn`
- **BuildingInspector** [PanelContainer]
- **@MarginContainer@48133** [MarginContainer]
  - **@VBoxContainer@48134** [VBoxContainer]
    - **@HBoxContainer@48135** [HBoxContainer]
      - **Icon** [TextureRect]
      - **NameLabel** [Label]
    - **@HSeparator@48136** [HSeparator]
    - **StatsLabel** [RichTextLabel]
    - **@HBoxContainer@48138** [HBoxContainer]
      - **@Label@48139** [Label]
      - **BtnRemove** [Button]
      - **WorkerCountLabel** [Label]
      - **BtnAdd** [Button]

### `res:///ui/components/HeirCard.tscn`
- **HeirCard** [PanelContainer]
- **VBox** [VBoxContainer]
  - **PortraitContainer** [Control]
    - **Portrait** [TextureRect]
    - **HeirCrown** [TextureRect]
    - **StatusIcon** [TextureRect]
  - **NameLabel** [Label]
  - **StatsLabel** [Label]

### `res:///ui/components/TreasuryHud.tscn`
- **TreasuryHUD** [PanelContainer]
- **HBoxContainer** [HBoxContainer]
  - **TreasuryDisplay** [HBoxContainer]
    - **GoldIcon** [TextureRect]
    - **GoldLabel** [Label]
    - **WoodIcon** [TextureRect]
    - **WoodLabel** [Label]
    - **FoodIcon** [TextureRect]
    - **FoodLabel** [Label]
    - **StoneIcon** [TextureRect]
    - **StoneLabel** [Label]
    - **VSeparator** [VSeparator]
    - **PeasantIcon** [TextureRect]
    - **PeasantLabel** [Label]
    - **ThrallIcon** [TextureRect]
    - **ThrallLabel** [Label]
    - **VSeparator2** [VSeparator]
    - **UnitCountLabel** [Label]

### `res:///ui/components/WorkerTag.tscn`
- **WorkerTag** [Control]
- **Panel** [PanelContainer]
  - **VBox** [VBoxContainer]
    - **HBox_Peasant** [HBoxContainer]
      - **Btn_Minus** [Button]
      - **CountLabel** [Label]
      - **Btn_Plus** [Button]
    - **HSeparator** [HSeparator]
    - **HBox_Thrall** [HBoxContainer]
      - **Btn_Minus** [Button]
      - **CountLabel** [Label]
      - **Btn_Plus** [Button]

### `res:///ui/seasonal/SeasonalCardUi.tscn`
- **SeasonalCard_UI** [Control]
- **PanelContainer** [PanelContainer]
  - **VBoxContainer** [VBoxContainer]
    - **TitleLabel** [Label]
    - **DescriptionLabel** [Label]
    - **IconRect** [TextureRect]
    - **CostContainer** [HBoxContainer]
      - **APCostLabel** [Label]
      - **GoldCostLabel** [Label]
    - **SelectButton** [Button]

### `res:///ui/seasonal/SummerAllocation_Ui.tscn`
- **SummerAllocation_UI** [Control]
- **Panel** [Panel]
  - **MarginContainer** [MarginContainer]
    - **VBoxContainer** [VBoxContainer]
      - **Header** [HBoxContainer]
        - **Title** [Label]
        - **PopulationLabel** [Label]
        - **UnassignedLabel** [Label]
      - **CardContainer** [HBoxContainer]
        - **ConstructionCard** [PanelContainer]
          - **Margin** [MarginContainer]
            - **VBox** [VBoxContainer]
              - **Title** [Label]
              - **HSeparator** [HSeparator]
              - **HBox** [HBoxContainer]
                - **ValConstruction** [Label]
                - **Label** [Label]
              - **ConstructionSlider** [HSlider]
              - **Spacer** [Control]
              - **LabelProj** [Label]
              - **Proj_Construction** [Label]
        - **FarmingCard** [PanelContainer]
          - **Margin** [MarginContainer]
            - **VBox** [VBoxContainer]
              - **Title** [Label]
              - **HSeparator** [HSeparator]
              - **HBox** [HBoxContainer]
                - **ValFarming** [Label]
                - **Label** [Label]
              - **FarmingSlider** [HSlider]
              - **Spacer** [Control]
              - **LabelProj** [Label]
              - **Proj_Food** [Label]
        - **RaidingCard** [PanelContainer]
          - **Margin** [MarginContainer]
            - **VBox** [VBoxContainer]
              - **Title** [Label]
              - **HSeparator** [HSeparator]
              - **HBox** [HBoxContainer]
                - **ValRaiding** [Label]
                - **Label** [Label]
              - **RaidingSlider** [HSlider]
              - **Spacer** [Control]
              - **LabelProj** [Label]
              - **Proj_Raid** [Label]
              - **CommitRaidBtn** [Button]
      - **WinterForecastPanel** [PanelContainer]
        - **Margin** [MarginContainer]
          - **HBox** [HBoxContainer]
            - **Lbl_Stockpile** [Label]
            - **VSeparator** [VSeparator]
            - **Lbl_WinterDemand** [Label]
            - **VSeparator2** [VSeparator]
            - **Lbl_WinterNet** [Label]
      - **Footer** [HBoxContainer]
        - **ConfirmBtn** [Button]

## 📜 SCRIPT API (Logic Structures)

### `res:///addons/GodotAiSuite/godot_ai_suite.gd`
```gdscript
extends EditorPlugin
var suite_container: HBoxContainer = HBoxContainer.new() # The main container for the toolbar UI
var settings_button: Button = Button.new()
var prompts_button: Button = Button.new() # Button for the prompt library
var export_button: Button = Button.new()
var settings_window: AcceptDialog = AcceptDialog.new()
var _prompt_library_instance: Window # The instance of our new scene
var _tab_container: TabContainer
var include_system_prompt_button: CheckButton = CheckButton.new()
var include_gdd_button: CheckButton = CheckButton.new()
var include_devlog_button: CheckButton = CheckButton.new()
var include_project_settings_button: CheckButton = CheckButton.new()
var include_resources_button: CheckButton = CheckButton.new()
var include_scenes_button: CheckButton = CheckButton.new()
var include_code_button: CheckButton = CheckButton.new()
var _scene_exclusion_tree: Tree
var _script_exclusion_tree: Tree
var _total_tokens_label: Label
var _system_prompt_token_count: int = 0
var _gdd_token_count: int = 0
var _devlog_token_count: int = 0
var _project_settings_token_count: int = 0
var _resources_token_count: int = 0
const PROMPT_LIBRARY_SCENE = preload("res://addons/GodotAiSuite/prompt_library/prompt_library.tscn")
const PROMPT_LIBRARY_ICON: Texture2D = preload("res://addons/GodotAiSuite/assets/prompt_library_icon.png")
const SYSTEM_PROMPT_FILE_PATH: String = "res://addons/GodotAiSuite/system_prompt.txt"
const DEVLOG_FILE_PATH: String = "res://addons/GodotAiSuite/DevLog.txt"
const GDD_FILE_PATH: String =  "res://addons/GodotAiSuite/GDD.txt"
const OUTPUT_FILE_PATH: String = "res://addons/GodotAiSuite/Masterprompt.txt"
const SETTINGS_FILE_PATH: String = "res://addons/GodotAiSuite/settings.cfg"
const TOKEN_RATIO_TEXT: float = 0.25   # For prose-like text (GDD, DevLog)
const TOKEN_RATIO_SCRIPT: float = 0.303 # For GDScript, C#, Shaders
const TOKEN_RATIO_SCENE: float = 0.4125 # For TSCN, TRES, and other structured data
const IGNORED_FILE_PATHS: Array[String] = [
const IGNORED_PROPERTIES: Array[String] = [
func _enter_tree() -> void:
	var suite_label: Label = Label.new()
func _exit_tree() -> void:
func _create_settings_window() -> void:
	var main_vbox: VBoxContainer = VBoxContainer.new()
	var general_vbox: VBoxContainer = VBoxContainer.new()
	var general_margin: MarginContainer = MarginContainer.new()
	var scene_tab_result: Dictionary = _create_file_exclusion_tab("Scene Exclusions", ["tscn"])
	var script_tab_result: Dictionary = _create_file_exclusion_tab("Script Exclusions", ["gd", "cs"])
	var token_margin := MarginContainer.new()
func _create_file_exclusion_tab(p_title: String, p_extensions: Array[String]) -> Dictionary:
	var vbox: VBoxContainer = VBoxContainer.new()
	var margin: MarginContainer = MarginContainer.new()
	var hbox: HBoxContainer = HBoxContainer.new()
	var select_all_button: Button = Button.new()
	var select_none_button: Button = Button.new()
	var tree: Tree = Tree.new()
func _populate_file_tree(p_tree: Tree, p_extensions: Array[String]) -> void:
	var root: TreeItem = p_tree.create_item()
	var files: Array = _find_files_by_extension(p_extensions)
	var valid_files: Array = files.filter(func(p): return not p in IGNORED_FILE_PATHS)
		var item: TreeItem = p_tree.create_item(root)
		var file_content: String
		var ratio: float
		var extension: String = file_path.get_extension()
			var scene_res: Resource = load(file_path)
				var scene_node: Node = scene_res.instantiate()
		var token_count: int = _calculate_tokens(file_content.length(), ratio)
func _on_settings_button_pressed() -> void:
func _on_prompts_button_pressed() -> void:
func _on_setting_changed(_is_toggled: bool) -> void:
func _on_file_selection_changed() -> void:
func _on_select_all_pressed(p_tree: Tree) -> void:
func _on_select_none_pressed(p_tree: Tree) -> void:
func _set_all_tree_items_checked(p_tree: Tree, p_checked: bool) -> void:
	var root: TreeItem = p_tree.get_root()
	var item: TreeItem = root.get_first_child()
func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
		var excluded_scenes: Array[String] = config.get_value("Exclusions", "excluded_scenes", []) as Array[String]
		var excluded_scripts: Array[String] = config.get_value("Exclusions", "excluded_scripts", []) as Array[String]
func _apply_exclusions_to_tree(p_tree: Tree, p_exclusions: Array[String]) -> void:
	var root: TreeItem = p_tree.get_root()
	var item: TreeItem = root.get_first_child()
		var metadata: Dictionary = item.get_metadata(0)
func _on_export_button_pressed() -> void:
	var heading_numbers: Dictionary = {}
	var main_heading_counter: int = 5 if include_system_prompt_button.button_pressed else 1
	var is_any_data_included: bool = (include_gdd_button.button_pressed and FileAccess.file_exists(GDD_FILE_PATH)) or \
	var excluded_files: Array[String] = _get_excluded_files_from_tree(_scene_exclusion_tree) + \
	var final_ignored_paths: Array[String] = IGNORED_FILE_PATHS + excluded_files
	var is_project_context_included: bool = include_project_settings_button.button_pressed or \
		var project_context_number: int = main_heading_counter
		var sub_heading_counter: int = 1
	var output: String = ""
		var context_spec: String = "### **%s. Project Context Specification**\n\n" % heading_numbers.specification
		var main_scene_path: String = ProjectSettings.get_setting("application/run/main_scene")
			var files: Array = _find_files_by_extension(["tres", "gdshader"])
			var blocks: Array = files.filter(func(p): return not p in final_ignored_paths).map(func(p): return "--- RESOURCE: %s ---\n" % p + FileAccess.get_file_as_string(p).rstrip(" \n"))
			var files: Array = _find_files_by_extension(["tscn"])
			var blocks: Array = []
				var block: String = "--- SCENE: %s ---\n" % file_path
				var scene_res: Resource = load(file_path)
			var files: Array = _find_files_by_extension(["gd", "cs"])
			var blocks: Array = files.filter(func(p): return not p in final_ignored_paths).map(func(p): return "--- SCRIPT: %s ---\n" % p + FileAccess.get_file_as_string(p).rstrip(" \n"))
	var file: FileAccess = FileAccess.open(OUTPUT_FILE_PATH, FileAccess.WRITE)
		var dialog: ConfirmationDialog = ConfirmationDialog.new(); dialog.title = "Export Successful"; dialog.dialog_text = "Project context exported to:\n%s" % OUTPUT_FILE_PATH; dialog.ok_button_text = "Open Folder"; dialog.get_cancel_button().text = "Close"
func _open_output_folder() -> void:
	var absolute_file_path: String = ProjectSettings.globalize_path(OUTPUT_FILE_PATH)
func _calculate_tokens(p_content_length: int, p_ratio: float) -> int:
func _update_category_token_counts() -> void:
	var resource_files: Array = _find_files_by_extension(["tres", "gdshader"])
		var ratio: float = TOKEN_RATIO_SCRIPT if file_path.get_extension() == "gdshader" else TOKEN_RATIO_SCENE
		var content_length: int = FileAccess.get_file_as_string(file_path).length()
func _get_excluded_files_from_tree(p_tree: Tree) -> Array[String]:
	var excluded_files: Array[String] = []
	var root: TreeItem = p_tree.get_root()
	var item: TreeItem = root.get_first_child()
			var metadata: Dictionary = item.get_metadata(0)
func _update_ui_and_token_counts() -> void:
	var selected_scene_tokens: int = _get_checked_token_sum_from_tree(_scene_exclusion_tree)
	var excluded_scene_count: int = _get_unchecked_item_count_from_tree(_scene_exclusion_tree)
	var scene_label: String = "Include Scene Structures (.tscn) (~%d tokens selected" % selected_scene_tokens
	var selected_code_tokens: int = _get_checked_token_sum_from_tree(_script_exclusion_tree)
	var excluded_code_count: int = _get_unchecked_item_count_from_tree(_script_exclusion_tree)
	var code_label: String = "Include Codebase (.gd, .cs) (~%d tokens selected" % selected_code_tokens
	var total_tokens: int = 0
func _get_checked_token_sum_from_tree(p_tree: Tree) -> int:
	var token_sum: int = 0
	var root: TreeItem = p_tree.get_root()
	var item: TreeItem = root.get_first_child()
			var metadata: Dictionary = item.get_metadata(0)
func _get_unchecked_item_count_from_tree(p_tree: Tree) -> int:
	var count: int = 0
	var root: TreeItem = p_tree.get_root()
	var item: TreeItem = root.get_first_child()
func _find_files_by_extension(extensions: Array) -> Array:
	var files: Array = []
	var dir: DirAccess = DirAccess.open("res://")
		var file_name: String = dir.get_next()
func _recursive_find(path: String, extensions: Array, files: Array) -> void:
	var dir: DirAccess = DirAccess.open(path)
		var file_name: String = dir.get_next()
func _value_to_string(value) -> String:
			var scene_path: String = "res://<UNKNOWN>"
func _get_node_data(node: Node, indent_level: int, scene_root: Node) -> String:
	var indent_str: String = ""
	var node_info: String = "%s%s (%s)\n" % [indent_str, node.name, node.get_class()]
	var details_indent: String = "> " + "  ".repeat(indent_level)
		var script_path: String = node.get_script().get_path()
	var groups: Array = node.get_groups()
	var prop_info: String = ""
	var default_node: Node = ClassDB.instantiate(node.get_class())
			var prop_name: String = prop.name
			var current_value = node.get(prop_name)
			var default_value = default_node.get(prop_name)
				var prop_value_str: String = _value_to_string(current_value)
func _are_values_equal(a, b) -> bool:
```

### `res:///addons/GodotAiSuite/prompt_library/prompt_library.gd`
```gdscript
extends Window
const PROMPT_LIBRARY_FILE_PATH: String = "res://addons/GodotAiSuite/prompt_library/prompts.json"
@onready var _search_bar: LineEdit = $MarginContainer/HSplitContainer/VBoxContainer/SearchBar
@onready var _prompt_tree: Tree = $MarginContainer/HSplitContainer/VBoxContainer/PromptTree
@onready var _title_label: Label = $MarginContainer/HSplitContainer/VBoxContainer2/TitleLabel
@onready var _description_label: Label = $MarginContainer/HSplitContainer/VBoxContainer2/DescriptionLabel
@onready var _prompt_text: TextEdit = $MarginContainer/HSplitContainer/VBoxContainer2/PromptText
@onready var _copy_button: Button = $MarginContainer/HSplitContainer/VBoxContainer2/HBoxContainer/CopyButton
@onready var _copy_feedback_label: Label = $MarginContainer/HSplitContainer/VBoxContainer2/HBoxContainer/CopyFeedbackLabel
var _prompts_data: Array = []
var _tree_category_items: Dictionary = {}
func _ready() -> void:
func popup_library() -> void:
func _on_search_changed(new_text: String) -> void:
func _on_tree_selected() -> void:
	var selected_item: TreeItem = _prompt_tree.get_selected()
	var prompt_index = selected_item.get_metadata(0)
		var prompt_data: Dictionary = _prompts_data[prompt_index]
		var prompt_path: String = prompt_data.get("prompt_file", "")
			var file: FileAccess = FileAccess.open(prompt_path, FileAccess.READ)
func _on_copy_pressed() -> void:
	var tween: Tween = create_tween()
func _load_and_populate_tree() -> void:
	var file: FileAccess = FileAccess.open(PROMPT_LIBRARY_FILE_PATH, FileAccess.READ)
	var content: String = file.get_as_text()
	var json: JSON = JSON.new()
	var error: Error = json.parse(content)
	var root: TreeItem = _prompt_tree.create_item()
		var prompt: Dictionary = _prompts_data[i]
		var category_name: String = prompt.get("category", "Uncategorized")
		var title: String = prompt.get("title", "Untitled Prompt")
		var category_item: TreeItem
		var prompt_item: TreeItem = _prompt_tree.create_item(category_item)
func _filter_tree(query: String) -> void:
	var root: TreeItem = _prompt_tree.get_root()
	var category_item: TreeItem = root.get_first_child()
		var category_visible: bool = false
		var prompt_item: TreeItem = category_item.get_first_child()
			var title: String = prompt_item.get_text(0).to_lower()
			var prompt_visible: bool = query.is_empty() or title.contains(query)
```

### `res:///addons/gut/GutScene.gd`
```gdscript
extends Node2D
@onready var _normal_gui = $Normal
@onready var _compact_gui = $Compact
var gut = null :
func _ready():
func _test_running_setup():
func _set_gut(val):
func _set_both_titles(text):
func _on_gut_start_run():
func _on_gut_end_run():
func _on_gut_pause():
func _on_pause_end():
func get_textbox():
func set_font_size(new_size):
	var rtl = _normal_gui.get_textbox()
func set_font(font_name):
func _set_font(rtl, font_name, custom_name):
		var font_path = 'res://addons/gut/fonts/' + font_name + '.ttf'
			var dyn_font = FontFile.new()
func _set_all_fonts_in_rtl(rtl, base_name):
func set_default_font_color(color):
func set_background_color(color):
func use_compact_mode(should=true):
func set_opacity(val):
func set_title(text):
```

### `res:///addons/gut/UserFileViewer.gd`
```gdscript
extends Window
@onready var rtl = $TextDisplay/RichTextLabel
func _get_file_as_text(path):
	var to_return = null
	var f = FileAccess.open(path, FileAccess.READ)
func _ready():
func _on_OpenFile_pressed():
func _on_FileDialog_file_selected(path):
func _on_Close_pressed():
func show_file(path):
	var text = _get_file_as_text(path)
func show_open():
func get_rich_text_label():
func _on_Home_pressed():
func _on_End_pressed():
func _on_Copy_pressed():
func _on_file_dialog_visibility_changed():
```

### `res:///addons/gut/autofree.gd`
```gdscript
var _to_free = []
var _to_queue_free = []
var _ref_counted_doubles = []
var _all_instance_ids = []
func _add_instance_id(thing):
func add_free(thing):
func add_queue_free(thing):
func get_queue_free_count():
func get_free_count():
func free_all():
func has_instance_id(id):
```

### `res:///addons/gut/awaiter.gd`
```gdscript
extends Node
	var _time_waited = 0.0
	var logger = GutUtils.get_logger()
	var waiting_on = "nothing"
	var logged_initial_message = false
	var wait_log_delay := 1.0
	var disabled = false
	func waited(x):
	func reset():
	func log_it():
			var msg = str("--- Awaiting ", waiting_on, " ---")
signal timeout
signal wait_started
var await_logger = AwaitLogger.new()
var _wait_time := 0.0
var _wait_process_frames := 0
var _wait_physics_frames := 0
var _signal_to_wait_on = null
var _predicate_method = null
var _waiting_for_predicate_to_be = null
var _predicate_time_between := 0.0
var _predicate_time_between_elpased := 0.0
var _elapsed_time := 0.0
var _elapsed_frames := 0
var _did_last_wait_timeout = false
var did_last_wait_timeout = false :
func _ready() -> void:
func _on_tree_process_frame():
func _on_tree_physics_frame():
func _physics_process(delta):
			var result = _predicate_method.call()
func _end_wait():
const ARG_NOT_SET = '_*_argument_*_is_*_not_set_*_'
func _signal_callback(
func wait_seconds(x, msg=''):
func wait_process_frames(x, msg=''):
func wait_physics_frames(x, msg=''):
func wait_for_signal(the_signal : Signal, max_time, msg=''):
func wait_until(predicate_function: Callable, max_time, time_between_calls:=0.0, msg=''):
func wait_while(predicate_function: Callable, max_time, time_between_calls:=0.0, msg=''):
func is_waiting():
```

### `res:///addons/gut/cli/change_project_warnings.gd`
```gdscript
extends SceneTree
var Optparse = load('res://addons/gut/cli/optparse.gd')
var WarningsManager = load("res://addons/gut/warnings_manager.gd")
const WARN_VALUE_PRINT_POSITION = 36
var godot_default_warnings = {
var gut_default_changes = {
var warning_settings = {}
func _setup_warning_settings():
	var gut_default = godot_default_warnings.duplicate()
func _warn_value_to_s(value):
	var readable = str(value).capitalize()
func _human_readable(warnings):
	var to_return = ""
		var readable = _warn_value_to_s(warnings[key])
func _dump_settings(which):
func _print_settings(which):
func _apply_settings(which):
	var pre_settings = warning_settings["current"]
	var new_settings = warning_settings[which]
func _diff_text(w1, w2, diff_col_pad=10):
	var to_return = ""
		var v1_text = _warn_value_to_s(w1[key])
		var v2_text = _warn_value_to_s(w2[key])
		var diff_text = v1_text
		var prefix = "  "
			var diff_prefix = " "
func _diff_changes_text(pre_settings):
	var orig_diff_text = _diff_text(
	var diff_text = orig_diff_text.replace("-", " -> ")
func _diff(name_1, name_2):
		var c2_pad = name_1.length() + 2
		var heading = str(" ".repeat(WARN_VALUE_PRINT_POSITION), name_1.rpad(c2_pad, ' '), name_2, "\n")
		var text = _diff_text(warning_settings[name_1], warning_settings[name_2], c2_pad)
		var diff_count = 0
func _set_settings(nvps):
	var pre_settings = warning_settings["current"]
		var s_name = nvps[i * 2]
		var s_value = nvps[i * 2 + 1]
			var t = typeof(godot_default_warnings[s_name])
func _setup_options():
	var opts = Optparse.new()
func _print_help(opts):
func _init():
	var opts = _setup_options()
```

### `res:///addons/gut/cli/gut_cli.gd`
```gdscript
extends Node
var Optparse = load('res://addons/gut/cli/optparse.gd')
var Gut = load('res://addons/gut/gut.gd')
var GutRunner = load('res://addons/gut/gui/GutRunner.tscn')
	var base_opts = {}
	var cmd_opts = {}
	var config_opts = {}
	func get_value(key):
	func set_base_opts(opts):
	func _null_copy(h):
		var new_hash = {}
	func _nvl(a, b):
	func _string_it(h):
		var to_return = ''
	func to_s():
	func get_resolved_values():
		var to_return = {}
	func to_s_verbose():
		var to_return = ''
		var resolved = get_resolved_values()
var _gut_config = load('res://addons/gut/gut_config.gd').new()
var _final_opts = []
func setup_options(options, font_names):
	var opts = Optparse.new()
	var o = opts.add('-graie', false, 'do not use')
func extract_command_line_options(from, to):
func _print_gutconfigs(values):
	var header = """Here is a sample of a full .gutconfig.json file.
	var resolved = values
func _run_tests(opt_resolver):
	var runner = GutRunner.instantiate()
func main():
	var opt_resolver = OptionResolver.new()
	var cli_opts = setup_options(_gut_config.default_options, _gut_config.valid_fonts)
	var all_options_valid = cli_opts.unused.size() == 0
	var config_path = opt_resolver.get_value('config_file')
	var load_result = 1
```

### `res:///addons/gut/cli/optparse.gd`
```gdscript
	var _has_been_set = false
	var _value = null
	var value = _value:
	var option_name = ''
	var default = null
	var description = ''
	var required = false
	var aliases: Array[String] = []
	var show_in_help = true
	func _init(name,default_value,desc=''):
	func wrap_text(text, left_indent, max_length, wiggle_room=15):
		var line_indent = str("\n", " ".repeat(left_indent + 1))
		var wrapped = ''
		var position = 0
		var split_length = max_length
			var split_by = split_length
				var min_space = text.rfind(' ', position + split_length)
				var max_space = text.find(' ', position + split_length)
	func to_s(min_space=0, wrap_length=100):
		var line_indent = str("\n", " ".repeat(min_space + 1))
		var subbed_desc = description
		var final = str(option_name.rpad(min_space), ' ', subbed_desc)
	func has_been_set():
	var options = []
	var display = 'default'
	var options = []
	var positional = []
	var default_heading = OptionHeading.new()
	var script_option = Option.new('-s', '?', 'script option provided by Godot')
	var _options_by_name = {"--script": script_option, "-s": script_option}
	var _options_by_heading = [default_heading]
	var _cur_heading = default_heading
	func add_heading(display):
		var heading = OptionHeading.new()
	func add(option, aliases=null):
	func add_positional(option):
	func get_by_name(option_name):
		var found_param = null
	func get_help_text():
		var longest = 0
		var text = ""
	func get_option_value_text():
		var text = ""
		var i = 0
	func print_option_values():
	func get_missing_required_options():
		var to_return = []
	func get_usage_text():
		var pos_text = ""
var options := Options.new()
var banner := ''
var option_name_prefix := '-'
var unused = []
var parsed_args = []
var values: Dictionary = {}
func _populate_values_dictionary():
		var value_key = entry.option_name.lstrip('-')
		var value_key = entry.option_name.lstrip('-')
func _convert_value_to_array(raw_value):
	var split = raw_value.split(',')
func _set_option_value(option, raw_value):
	var t = typeof(option.default)
		var values = _convert_value_to_array(raw_value)
func _parse_command_line_arguments(args):
	var parsed_opts = args.duplicate()
	var i = 0
	var positional_index = 0
		var opt  = ''
		var value = ''
		var entry = parsed_opts[i]
				var parts = entry.split('=')
				var the_option = options.get_by_name(opt)
				var the_option = options.get_by_name(entry)
func is_option(arg) -> bool:
func add(op_names, default, desc: String) -> Option:
	var op_name: String
	var aliases: Array[String] = []
	var new_op: Option = null
	var bad_alias: int = aliases.map(
		func (a: String) -> bool: return options.get_by_name(a) != null
func add_required(op_names, default, desc: String) -> Option:
	var op := add(op_names, default, desc)
func add_positional(op_name, default, desc: String) -> Option:
	var new_op = null
func add_positional_required(op_name, default, desc: String) -> Option:
	var op = add_positional(op_name, default, desc)
func add_heading(display_text: String) -> void:
func get_value(name: String):
	var found_param: Option = options.get_by_name(name)
func get_value_or_null(name: String):
	var found_param: Option = options.get_by_name(name)
func get_help() -> String:
	var sep := '---------------------------------------------------------'
	var text := str(sep, "\n", banner, "\n\n")
func print_help() -> void:
func parse(cli_args=null) -> void:
func get_missing_required_options() -> Array:
```

### `res:///addons/gut/collected_script.gd`
```gdscript
var CollectedTest = GutUtils.CollectedTest
var _lgr = null
var tests = []
var setup_teardown_tests = []
var inner_class_name:StringName
var path:String
var is_loaded = false
var was_skipped = false
var skip_reason = ''
var was_run = false
var name = '' :
func _init(logger=null):
func get_new():
	var inst = load_script().new()
func load_script():
	var to_return = load(path)
func get_filename_and_inner():
	var to_return = get_filename()
func get_full_name():
	var to_return = path
func get_filename():
func has_inner_class():
func export_to(config_file, section):
	var names = []
func _remap_path(source_path):
	var to_return = source_path
		var remap_path = source_path.get_basename() + '.gd.remap'
			var cf = ConfigFile.new()
func import_from(config_file, section):
	var inner_name = config_file.get_value(section, 'inner_class', 'Placeholder')
func get_test_named(test_name):
func get_ran_test_count():
	var count = 0
func get_assert_count():
	var count = 0
func get_pass_count():
	var count = 0
func get_fail_count():
	var count = 0
func get_pending_count():
	var count = 0
func get_passing_test_count():
	var count = 0
func get_failing_test_count():
	var count = 0
func get_risky_count():
	var count = 0
func to_s():
	var to_return = path
```

### `res:///addons/gut/collected_test.gd`
```gdscript
var name = ""
var has_printed_name = false
var arg_count = 0
var time_taken : float = 0
var assert_count = 0 :
var pending = false :
var line_number = -1
var should_skip = false  # -- Currently not used by GUT don't believe ^
var pass_texts = []
var fail_texts = []
var pending_texts = []
var orphans = 0
var was_run = false
var collected_script : WeakRef = null
func did_pass():
func add_fail(fail_text):
func add_pending(pending_text):
func add_pass(passing_text):
func is_passing():
func is_failing():
func is_pending():
func is_risky():
func did_something():
func get_status_text():
	var to_return = GutUtils.TEST_STATUSES.NO_ASSERTS
func get_status():
func to_s():
	var pad = '     '
	var to_return = str(name, "[", get_status_text(), "]\n")
```

### `res:///addons/gut/comparator.gd`
```gdscript
var _strutils = GutUtils.Strutils.new()
var _max_length = 100
var _should_compare_int_to_float = true
const MISSING = '|__missing__gut__compare__value__|'
func _cannot_compare_text(v1, v2):
func _make_missing_string(text):
func _create_missing_result(v1, v2, text):
	var to_return = null
	var v1_str = format_value(v1)
	var v2_str = format_value(v2)
func simple(v1, v2, missing_string=''):
	var missing_result = _create_missing_result(v1, v2, missing_string)
	var result = GutUtils.CompareResult.new()
	var cmp_str = null
	var extra = ''
	var tv1 = typeof(v1)
	var tv2 = typeof(v2)
			var sub_result = GutUtils.DiffTool.new(v1, v2, GutUtils.DIFF.DEEP)
func shallow(v1, v2):
	var result =  null
func deep(v1, v2):
	var result =  null
func format_value(val, max_val_length=_max_length):
func compare(v1, v2, diff_type=GutUtils.DIFF.SIMPLE):
	var result = null
func get_should_compare_int_to_float():
func set_should_compare_int_to_float(should_compare_int_float):
func get_compare_symbol(is_equal):
```

### `res:///addons/gut/compare_result.gd`
```gdscript
var _are_equal = false
var are_equal = false :
var _summary = null
var summary = null :
var _max_differences = 30
var max_differences = 30 :
var _differences = {}
var differences :
func _block_set(which, val):
func _to_string():
func get_are_equal():
func set_are_equal(r_eq):
func get_summary():
func set_summary(smry):
func get_total_count():
func get_different_count():
func get_short_summary():
func get_max_differences():
func set_max_differences(max_diff):
func get_differences():
func set_differences(diffs):
func get_brackets():
```

### `res:///addons/gut/diff_formatter.gd`
```gdscript
var _strutils = GutUtils.Strutils.new()
const INDENT = '    '
var _max_to_display = 30
const ABSOLUTE_MAX_DISPLAYED = 10000
const UNLIMITED = -1
func _single_diff(diff, depth=0):
	var to_return = ""
	var brackets = diff.get_brackets()
func make_it(diff):
	var to_return = ''
func differences_to_s(differences, depth=0):
	var to_return = ''
	var keys = differences.keys()
	var limit = min(_max_to_display, differences.size())
		var key = keys[i]
func get_max_to_display():
func set_max_to_display(max_to_display):
```

### `res:///addons/gut/diff_tool.gd`
```gdscript
extends 'res://addons/gut/compare_result.gd'
const INDENT = '    '
enum {
var _strutils = GutUtils.Strutils.new()
var _compare = GutUtils.Comparator.new()
var _value_1 = null
var _value_2 = null
var _total_count = 0
var _diff_type = null
var _brackets = null
var _valid = true
var _desc_things = 'somethings'
func set_are_equal(val):
func get_are_equal():
func set_summary(val):
func get_summary():
func get_different_count():
func  get_total_count():
func get_short_summary():
	var text = str(_strutils.truncate_string(str(_value_1), 50),
func get_brackets():
func _invalidate():
func _init(v1,v2,diff_type=DEEP):
func _find_differences(v1, v2):
func _diff_array(a1, a2):
		var result = null
func _diff_dictionary(d1, d2):
	var d1_keys = d1.keys()
	var d2_keys = d2.keys()
			var result = null
func summarize():
	var summary = ''
		var formatter = load('res://addons/gut/diff_formatter.gd').new()
func get_diff_type():
func get_value_1():
func get_value_2():
```

### `res:///addons/gut/double_tools.gd`
```gdscript
var thepath = ''
var subpath = ''
var from_singleton = null
var is_partial = null
var double_ref : WeakRef = null
var stubber_ref : WeakRef = null
var spy_ref : WeakRef = null
var gut_ref : WeakRef = null
const NO_DEFAULT_VALUE = '!__gut__no__default__value__!'
func _init(double = null):
		var values = double.__gutdbl_values
func _get_stubbed_method_to_call(method_name, called_with):
	var method = stubber_ref.get_ref().get_call_this(double_ref.get_ref(), method_name, called_with)
func weakref_from_id(inst_id):
func is_stubbed_to_call_super(method_name, called_with):
func handle_other_stubs(method_name, called_with):
	var method = _get_stubbed_method_to_call(method_name, called_with)
func spy_on(method_name, called_with):
func default_val(method_name, p_index):
```

### `res:///addons/gut/doubler.gd`
```gdscript
extends RefCounted
var _base_script_text = GutUtils.get_file_as_text('res://addons/gut/double_templates/script_template.txt')
var _script_collector = GutUtils.ScriptCollector.new()
var print_source = false
var inner_class_registry = GutUtils.InnerClassRegistry.new()
var _stubber = GutUtils.Stubber.new()
func get_stubber():
func set_stubber(stubber):
var _lgr = GutUtils.get_logger()
func get_logger():
func set_logger(logger):
var _spy = null
func get_spy():
func set_spy(spy):
var _gut = null
func get_gut():
func set_gut(gut):
var _strategy = null
func get_strategy():
func set_strategy(strategy):
var _method_maker = GutUtils.MethodMaker.new()
func get_method_maker():
var _ignored_methods = GutUtils.OneToMany.new()
func get_ignored_methods():
func _init(strategy=GutUtils.DOUBLE_STRATEGY.SCRIPT_ONLY):
func _get_indented_line(indents, text):
	var to_return = ''
func _stub_to_call_super(parsed, method_name):
	var params = GutUtils.StubParams.new(parsed.script_path, method_name, parsed.subpath)
func _get_base_script_text(parsed, override_path, partial, included_methods):
	var path = parsed.script_path
	var stubber_id = -1
	var spy_id = -1
	var gut_id = -1
	var extends_text  = parsed.get_extends_text()
	var values = {
func _is_method_eligible_for_doubling(parsed_script, parsed_method):
func _create_script_no_warnings(src):
	var prev_native_override_value = null
	var native_method_override = 'debug/gdscript/warnings/native_method_override'
	var DblClass = GutUtils.create_script_from_source(src)
func _create_double(parsed, strategy, override_path, partial):
	var dbl_src = ""
	var included_methods = []
	var base_script = _get_base_script_text(parsed, override_path, partial, included_methods)
		var to_print :String = GutUtils.add_line_numbers(dbl_src)
	var DblClass = _create_script_no_warnings(dbl_src)
func _stub_method_default_values(which, parsed, strategy):
func _double_scene_and_script(scene, strategy, partial):
	var dbl_bundle = scene._bundled.duplicate(true)
	var script_obj = GutUtils.get_scene_script_object(scene)
	var script_index = dbl_bundle["variants"].find(script_obj)
	var script_dbl = null
	var doubled_scene = PackedScene.new()
func _get_inst_id_ref_str(inst):
	var ref_str = 'null'
func _get_func_text(method_hash):
func _parse_script(obj):
	var parsed = null
func _double(obj, strategy, override_path=null):
	var parsed = _parse_script(obj)
func _partial_double(obj, strategy, override_path=null):
	var parsed = _parse_script(obj)
func double(obj, strategy=_strategy):
func partial_double(obj, strategy=_strategy):
func double_scene(scene, strategy=_strategy):
func partial_double_scene(scene, strategy=_strategy):
func double_gdnative(which):
func partial_double_gdnative(which):
func double_inner(parent, inner, strategy=_strategy):
	var parsed = _script_collector.parse(parent, inner)
func partial_double_inner(parent, inner, strategy=_strategy):
	var parsed = _script_collector.parse(parent, inner)
func add_ignored_method(obj, method_name):
```

### `res:///addons/gut/dynamic_gdscript.gd`
```gdscript
var default_script_name_no_extension = 'gut_dynamic_script'
var default_script_resource_path = 'res://addons/gut/not_a_real_file/'
var default_script_extension = "gd"
var _created_script_count = 0
func create_script_from_source(source, override_path=null):
	var r_path = str(default_script_resource_path,
	var DynamicScript = GDScript.new()
	var result = DynamicScript.reload()
```

### `res:///addons/gut/editor_caret_context_notifier.gd`
```gdscript
extends Node
var _last_info : Dictionary = {}
var _last_line = -1
var _current_script_editor : ScriptEditor = null
var _current_script = null
var _current_script_is_test_script = false
var _current_editor_base : ScriptEditorBase = null
var _current_editor : CodeEdit = null
var _editors_for_scripts : Dictionary= {}
var inner_class_prefix = "Test"
var method_prefix = "test_"
var script_prefix = "test_"
var script_suffix = ".gd"
signal it_changed(change_data)
func _ready():
func _handle_caret_location(which):
	var current_line = which.get_caret_line(0) + 1
			var new_info = _make_info(which, _current_script, _current_script_is_test_script)
func _get_func_name_from_line(text):
	var left = text.split("(")[0]
	var func_name = left.split(" ")[1]
func _get_class_name_from_line(text):
	var right = text.split(" ")[1]
	var the_name = right.rstrip(":")
func _make_info(editor, script, test_script_flag):
	var info = {
	var start_line = editor.get_caret_line()
	var line = start_line
	var done_func = false
	var done_inner = false
	while(line > 0 and (!done_func or !done_inner)):
			var text = editor.get_line(line)
			var strip_text = text.strip_edges(true, false) # only left
			if(!done_func and strip_text.begins_with("func ")):
				done_func = true
				var inner_name = _get_class_name_from_line(text)
					done_func = true
func _on_editor_script_changed(script):
func _on_editor_script_close(script):
	var script_editor = _editors_for_scripts.get(script, null)
func _on_caret_changed(which):
func _could_be_test_script(script):
var _scripts_that_have_been_warned_about = []
var _we_have_warned_enough = false
var _max_warnings = 5
func is_test_script(script):
	var base = script.get_base_script()
func get_info():
func log_values():
```

### `res:///addons/gut/error_tracker.gd`
```gdscript
extends Logger
class_name GutErrorTracker
static func register_logger(which):
static func deregister_logger(which):
var _current_test_id = GutUtils.NO_TEST
var _mutex = Mutex.new()
var errors = GutUtils.OneToMany.new()
var treat_gut_errors_as : GutUtils.TREAT_AS = GutUtils.TREAT_AS.FAILURE
var treat_engine_errors_as : GutUtils.TREAT_AS = GutUtils.TREAT_AS.FAILURE
var treat_push_error_as : GutUtils.TREAT_AS = GutUtils.TREAT_AS.FAILURE
var disabled = false
func _get_stack_data(current_test_name):
	var test_entry = {}
	var stackTrace = get_stack()
		var index = 0
			var line = stackTrace[index]
			var function = line.get("function")
func _is_error_failable(error : GutTrackedError):
	var is_it = false
func _log_error(function: String, file: String, line: int,
func start_test(test_id):
func end_test():
func did_test_error(test_id=_current_test_id):
func get_current_test_errors():
func should_test_fail_from_errors(test_id = _current_test_id):
	var to_return = false
		var errs = errors.items[test_id]
		var index = 0
			var error = errs[index]
func get_errors_for_test(test_id=_current_test_id):
	var to_return = []
func get_fail_text_for_errors(test_id=_current_test_id) -> String:
	var error_texts = []
	var to_return = ""
func add_gut_error(text) -> GutTrackedError:
		var data = _get_stack_data(_current_test_id)
func add_error(function: String, file: String, line: int,
		var err := GutTrackedError.new()
```

### `res:///addons/gut/get_editor_interface.gd`
```gdscript
func get_it():
```

### `res:///addons/gut/gui/GutBottomPanel.gd`
```gdscript
extends Control
var GutEditorGlobals = load('res://addons/gut/gui/editor_globals.gd')
var GutConfigGui = load('res://addons/gut/gui/gut_config_gui.gd')
var AboutWindow = load("res://addons/gut/gui/about.tscn")
var _interface = null;
var _is_running = false :
var _gut_config = load('res://addons/gut/gut_config.gd').new()
var _gut_config_gui = null
var _gut_plugin = null
var _light_color = Color(0, 0, 0, .5) :
var _panel_button = null
var _user_prefs = null
var _shell_out_panel = null
var menu_manager = null :
@onready var _ctrls = {
@onready var results_v_split = %VSplitResults
@onready var results_h_split = %HSplitResults
@onready var results_tree = %RunResults
@onready var results_text = %OutputText
@onready var make_floating_btn = %MakeFloating
func _ready():
	var check_import = load('res://addons/gut/images/HSplitContainer.svg')
func _process(_delta):
func _apply_options_to_controls():
	var shell_dialog_size = _user_prefs.run_externally_options_dialog_size.value
	var mode_ind = 'Ed'
func _disable_run_buttons(should):
func _is_test_script(script):
	var from = script.get_base_script()
func _show_errors(errs):
	var text = "Cannot run tests, you have a configuration error:\n"
func _save_user_prefs():
func _save_config():
	var w_result = _gut_config.write_options(GutEditorGlobals.editor_run_gut_config_path)
func _run_externally():
func _run_tests():
	var issues = _gut_config_gui.get_config_issues()
func _apply_shortcuts():
func _run_all():
func _on_results_bar_draw(bar):
func _on_Light_draw():
	var l = _ctrls.light
func _on_RunAll_pressed():
func _on_Shortcuts_pressed():
func _on_sortcut_dialog_confirmed() -> void:
func _on_RunAtCursor_run_tests(what):
func _on_Settings_pressed():
func _on_OutputBtn_pressed():
func _on_RunResultsBtn_pressed():
func _on_UseColors_pressed():
func _on_shell_out_options_confirmed() -> void:
func _on_run_mode_pressed() -> void:
func _on_toggle_windowed():
func _on_to_window_pressed() -> void:
func _on_show_gut() -> void:
func _on_about_pressed() -> void:
func load_shortcuts():
func hide_result_tree(should):
func hide_settings(should):
	var s_scroll = _ctrls.settings.get_parent()
func hide_output_text(should):
func clear_results():
func load_result_json():
	var summary = get_file_as_text(GutEditorGlobals.editor_run_json_results_path)
	var test_json_conv = JSON.new()
	var results = test_json_conv.get_data()
	var summary_json = results['test_scripts']['props']
func load_result_text():
func load_result_output():
func set_interface(value):
func set_plugin(value):
func set_panel_button(value):
func write_file(path, content):
	var f = FileAccess.open(path, FileAccess.WRITE)
func get_file_as_text(path):
	var to_return = ''
	var f = FileAccess.open(path, FileAccess.READ)
func get_text_output_control():
func add_output_text(text):
func show_about():
	var about = AboutWindow.instantiate()
func show_me():
func show_hide():
			var win_to_focus_on = EditorInterface.get_editor_main_screen().get_parent()
func get_shortcut_dialog():
func results_vert_layout():
func results_horiz_layout():
```

### `res:///addons/gut/gui/GutControl.gd`
```gdscript
extends Control
const RUNNER_JSON_PATH = 'res://.gut_editor_config.json'
var GutConfig = load('res://addons/gut/gut_config.gd')
var GutRunnerScene = load('res://addons/gut/gui/GutRunner.tscn')
var GutConfigGui = load('res://addons/gut/gui/gut_config_gui.gd')
var _config = GutConfig.new()
var _config_gui = null
var _gut_runner = null
var _tree_root : TreeItem = null
var _script_icon = load('res://addons/gut/images/Script.svg')
var _folder_icon = load('res://addons/gut/images/Folder.svg')
var _tree_scripts = {}
var _tree_directories = {}
const TREE_SCRIPT = 'Script'
const TREE_DIR = 'Directory'
@onready var _ctrls = {
@export var bg_color : Color = Color(.36, .36, .36) :
func _ready():
func _draw():
	var gut = _gut_runner.get_gut()
		var r = Rect2(Vector2(0, 0), get_rect().size)
func _post_ready():
	var gut = _gut_runner.get_gut()
func _set_meta_for_script_tree_item(item, script, test=null):
	var meta = {
func _set_meta_for_directory_tree_item(item, path, temp_item):
	var meta = {
func _get_script_tree_item(script, parent_item):
		var item = _ctrls.test_tree.create_item(parent_item)
func _get_directory_tree_item(path):
	var parent = _tree_root
		var item : TreeItem = null
		var temp_item = item.create_child()
func _find_dir_item_to_move_before(path):
	var max_matching_len = 0
	var best_parent = null
	var to_return = null
func _reorder_dir_items():
	var the_keys = _tree_directories.keys()
		var to_move = _tree_directories[key]
		var move_before = _find_dir_item_to_move_before(key)
			var new_text = key.substr(move_before.get_parent().get_metadata(0).path.length())
func _remove_dir_temp_items():
		var item = _tree_directories[key].get_metadata(0).temp_item
func _add_dir_and_script_tree_items():
	var tree : Tree = _ctrls.test_tree
	var scripts = _gut_runner.get_gut().get_test_collector().scripts
		var dir_item = _get_directory_tree_item(script.path.get_base_dir())
		var item = _get_script_tree_item(script, dir_item)
			var inner_item = tree.create_item(item)
			var test_item = tree.create_item(item)
func _populate_tree():
func _refresh_tree_and_settings():
func _on_gut_run_started():
func _on_gut_run_ended():
func _on_run_tests_pressed():
func _on_run_selected_pressed():
func _on_tests_item_activated():
func get_gut():
func get_config():
func run_all():
func run_tests(options = null):
func run_selected():
	var sel_item = _ctrls.test_tree.get_selected()
	var options = _config_gui.get_options(_config.options)
	var meta = sel_item.get_metadata(0)
func load_config_file(path):
```

### `res:///addons/gut/gui/GutEditorWindow.gd`
```gdscript
extends Window
var GutEditorGlobals = load('res://addons/gut/gui/editor_globals.gd')
@onready var _chk_always_on_top = $Layout/WinControls/OnTop
var _bottom_panel = null
var _ready_to_go = false
var _gut_shortcuts = []
var gut_plugin = null
var interface = null
func _unhandled_key_input(event: InputEvent) -> void:
func _ready() -> void:
	var pref_size = GutEditorGlobals.user_prefs.gut_window_size.value
func _on_on_top_toggled(toggled_on: bool) -> void:
func _on_size_changed() -> void:
func _on_close_requested() -> void:
func _on_vert_layout_pressed() -> void:
func _on_horiz_layout_pressed() -> void:
func add_gut_panel(panel : Control):
	var settings = interface.get_editor_settings()
func remove_panel():
func set_gut_shortcuts(shortcuts_dialog):
```

### `res:///addons/gut/gui/GutRunner.gd`
```gdscript
extends Node2D
const EXIT_OK = 0
const EXIT_ERROR = 1
var Gut = load('res://addons/gut/gut.gd')
var ResultExporter = load('res://addons/gut/result_exporter.gd')
var GutConfig = load('res://addons/gut/gut_config.gd')
var runner_json_path = null
var result_bbcode_path = null
var result_json_path = null
var lgr = GutUtils.get_logger()
var gut_config = null
var error_tracker = GutUtils.get_error_tracker()
var _hid_gut = null;
var gut = _hid_gut :
var _wrote_results = false
var _ran_from_editor = false
@onready var _gut_layer = $GutLayer
@onready var _gui = $GutLayer/GutScene
func _ready():
func _exit_tree():
func _setup_gui(show_gui):
		var printer = gut.logger.get_printer('gui')
	var opts = gut_config.options
func _write_results_for_gut_panel():
	var content = _gui.get_textbox().get_parsed_text() #_gut.logger.get_gui_bbcode()
	var f = FileAccess.open(result_bbcode_path, FileAccess.WRITE)
	var exporter = ResultExporter.new()
	var _f_result = exporter.write_json_file(gut, result_json_path)
func _handle_quit(should_exit, should_exit_on_success, override_exit_code=EXIT_OK):
	var quitting_time = should_exit or \
	var exit_code = GutUtils.nvl(override_exit_code, EXIT_OK)
	var post_hook_inst = gut.get_post_run_script_instance()
func _end_run(override_exit_code=EXIT_OK):
func _on_tests_finished():
func run_from_editor():
	var GutEditorGlobals = load('res://addons/gut/gui/editor_globals.gd')
func run_tests(show_gui=true):
		var err_text = "You do not have any directories configured, so GUT " + \
	var install_check_text = GutUtils.make_install_check_text()
	var run_rest_of_scripts = gut_config.options.unit_test_name == ''
func set_gut_config(which):
func get_gut():
func quit(exit_code):
```

### `res:///addons/gut/gui/OutputText.gd`
```gdscript
extends VBoxContainer
var GutEditorGlobals = load('res://addons/gut/gui/editor_globals.gd')
var PanelControls = load('res://addons/gut/gui/panel_controls.gd')
	var te : TextEdit
	var _last_term = ''
	var _last_pos = Vector2(-1, -1)
	var _ignore_caret_change = false
	func set_text_edit(which):
	func _on_caret_changed():
	func _get_caret():
	func _set_caret_and_sel(pos, len):
	func _find(term, search_flags):
		var pos = _get_caret()
		var result = te.search(term, search_flags, pos.y, pos.x)
	func find_next(term):
	func find_prev(term):
@onready var _ctrls = {
var _sr = TextEditSearcher.new()
var _highlighter : CodeHighlighter
var _font_name = null
var _user_prefs = GutEditorGlobals.user_prefs
var _font_name_pctrl = null
var _font_size_pctrl = null
var keywords = [
func _test_running_setup():
func _ready():
func _add_other_ctrls():
	var fname = GutUtils.gut_fonts.DEFAULT_CUSTOM_FONT_NAME
	var fsize = 30
func _refresh_output():
	var orig_pos = _ctrls.output.scroll_vertical
	var text = _ctrls.output.text
func _create_highlighter(default_color=Color(1, 1, 1, 1)):
	var to_return = CodeHighlighter.new()
func _setup_colors():
func _use_highlighting(should):
func _on_caret_changed():
	var txt = str("line:",_ctrls.output.get_caret_line(), ' col:', _ctrls.output.get_caret_column())
func _on_font_size_changed():
func _on_font_name_changed():
func _on_CopyButton_pressed():
func _on_UseColors_pressed():
func _on_ClearButton_pressed():
func _on_ShowSearch_pressed():
func _on_SearchTerm_focus_entered():
func _on_SearchNext_pressed():
func _on_SearchPrev_pressed():
func _on_SearchTerm_text_changed(new_text):
func _on_SearchTerm_text_entered(new_text):
func _on_SearchTerm_gui_input(event):
func _on_WordWrap_pressed():
func _on_settings_pressed():
func show_search(should):
func search(text, start_pos, highlight=true):
func copy_to_clipboard():
	var selected = _ctrls.output.get_selected_text()
func clear():
func _set_font(custom_name, theme_font_name):
	var font = GutUtils.gut_fonts.get_font_for_theme_font_name(theme_font_name, custom_name)
func set_all_fonts(base_name):
func set_font_size(new_size):
func set_use_colors(value):
func get_use_colors():
func get_rich_text_edit():
func load_file(path):
	var f = FileAccess.open(path, FileAccess.READ)
	var t = f.get_as_text()
func add_text(text):
func scroll_to_line(line):
```

### `res:///addons/gut/gui/ResizeHandle.gd`
```gdscript
extends ColorRect
enum ORIENTATION {
@export var orientation := ORIENTATION.RIGHT :
@export var resize_control : Control = null
@export var vertical_resize := true
var _line_width = .5
var _line_color = Color(.4, .4, .4)
var _active_line_color = Color(.3, .3, .3)
var _invalid_line_color = Color(1, 0, 0)
var _line_space = 3
var _num_lines = 8
var _mouse_down = false
func _draw():
	var c = _line_color
func _gui_input(event):
func _draw_resize_handle_right(draw_color):
	var br = size
		var start = br - Vector2(i * _line_space, 0)
		var end = br - Vector2(0, i * _line_space)
func _draw_resize_handle_left(draw_color):
	var bl = Vector2(0, size.y)
		var start = bl + Vector2(i * _line_space, 0)
		var end = bl -  Vector2(0, i * _line_space)
func _handle_right_input(event : InputEvent):
func _handle_left_input(event : InputEvent):
			var start_size = resize_control.size
```

### `res:///addons/gut/gui/ResultsTree.gd`
```gdscript
extends Tree
var _show_orphans = true
var show_orphans = true :
var _hide_passing = true
var hide_passing = true :
var _icons = {
@export var script_entry_color : Color = Color(0, 0, 0, .2) :
@export var column_0_color : Color = Color(1, 1, 1, 0) :
@export var column_1_color : Color = Color(0, 0, 0, .2):
var _max_icon_width = 10
var _root : TreeItem
@onready var lbl_overlay = $TextOverlay
signal selected(script_path, inner_class, test_name, line_number)
func _debug_ready():
func _ready():
func _get_line_number_from_assert_msg(msg):
	var line = -1
func _get_path_and_inner_class_name_from_test_path(path):
	var to_return = {
		var loc = path.find('.gd')
func _find_script_item_with_path(path):
	var items = _root.get_children()
	var to_return = null
	var idx = 0
		var item = items[idx]
func _add_script_tree_item(script_path, script_json):
	var path_info = _get_path_and_inner_class_name_from_test_path(script_path)
	var item_text = script_path
	var parent = _root
	var item = create_item(parent)
	var meta = {
func _add_assert_item(text, icon, parent_item):
	var assert_item = create_item(parent_item)
func _add_test_tree_item(test_name, test_json, script_item):
	var no_orphans_to_show = !_show_orphans or (_show_orphans and test_json.orphan_count == 0)
	var item = create_item(script_item)
	var status = test_json['status']
	var meta = {"type":"test", "json":test_json}
	var orphan_text = 'orphans'
		var orphan_item = _add_assert_item(orphan_text, _icons.yellow, item)
			var orphan_entry = create_item(orphan_item)
func _add_script_to_tree(key, script_json):
	var tests = script_json['tests']
	var test_keys = tests.keys()
	var s_item = _add_script_tree_item(key, script_json)
	var bad_count = 0
		var t_item = _add_test_tree_item(test_key, tests[test_key], s_item)
		var total_text = str('All ', test_keys.size(), ' passed')
func _free_childless_scripts():
	var items = _root.get_children()
		var next_item = item.get_next()
func _show_all_passed():
func _load_result_tree(j):
	var scripts = j['test_scripts']['scripts']
	var script_keys = scripts.keys()
	var add_count = 0
func _on_tree_item_selected():
	var item = get_selected()
	var item_meta = item.get_metadata(0)
	var item_type = null
	var script_path = '';
	var line = -1;
	var test_name = ''
	var inner_class = ''
		var s_item = item.get_parent()
		var s_item = item.get_parent().get_parent()
func load_json_file(path):
	var file = FileAccess.open(path, FileAccess.READ)
	var text = ''
		var test_json_conv = JSON.new()
		var result = test_json_conv.parse(text)
		var data = test_json_conv.get_data()
func load_json_results(j):
func set_summary_min_width(width):
func add_centered_text(t):
func clear_centered_text():
func collapse_all():
func expand_all():
func set_collapsed_on_all(item, value):
```

### `res:///addons/gut/gui/RunAtCursor.gd`
```gdscript
extends Control
var EditorCaretContextNotifier = load('res://addons/gut/editor_caret_context_notifier.gd')
@onready var _ctrls = {
var _caret_notifier = null
var _last_info = {
var disabled = false :
var method_prefix = 'test_'
var inner_class_prefix = 'Test'
var menu_manager = null :
signal run_tests(what)
func _ready():
func _on_caret_notifer_changed(data):
func _update_buttons(info):
	var is_test_method = info.method != null and info.method.begins_with(method_prefix)
func _update_size():
var _last_run_info = {}
func _emit_run_tests(info):
func _on_BtnRunScript_pressed():
	var info = _last_info.duplicate()
func _on_BtnRunInnerClass_pressed():
	var info = _last_info.duplicate()
func _on_BtnRunMethod_pressed():
	var info = _last_info.duplicate()
func rerun():
func run_at_cursor():
func get_script_button():
func get_inner_button():
func get_test_button():
func set_inner_class_prefix(value):
func apply_gut_config(gut_config):
```

### `res:///addons/gut/gui/RunExternally.gd`
```gdscript
extends Control
var GutEditorGlobals = load('res://addons/gut/gui/editor_globals.gd')
@onready var btn_kill_it = $BgControl/VBox/Kill
@onready var bg_control = $BgControl
var _pipe_results = {}
var _debug_mode = false
var _std_thread : Thread
var _escape_regex : RegEx = RegEx.new()
var _text_buffer = ''
var bottom_panel = null :
var blocking_mode = "Blocking"
var additional_arguments = []
var remove_escape_characters = true
@export var bg_color = Color.WHITE:
func _debug_ready():
func _ready():
func _process(_delta: float) -> void:
func _center_me():
func _output_text(text, should_scroll = true):
func _scroll_output_pane(line):
		var txt_ctrl = bottom_panel.get_text_output_control().get_rich_text_edit()
func _add_arguments_to_output():
func _load_json():
func _run_blocking(options):
	var output = []
func _read_non_blocking_stdio():
func _run_non_blocking(options):
func _end_non_blocking():
func _on_kill_pressed() -> void:
func _on_color_rect_gui_input(event: InputEvent) -> void:
func _on_bottom_panel_resized():
func run_tests():
	var options = ["-s", "res://addons/gut/gut_cmdln.gd", "-graie", "-gdisable_colors",
func get_godot_help():
	var options = ["--help", "--headless"]
func get_gut_help():
	var options = ["-s", "res://addons/gut/gut_cmdln.gd", "-gh", "--headless"]
```

### `res:///addons/gut/gui/RunResults.gd`
```gdscript
extends Control
var GutEditorGlobals = load('res://addons/gut/gui/editor_globals.gd')
var _interface = null
var _output_control = null
@onready var _ctrls = {
func _ready():
	var f = null
	var s_size = f.get_string_size("000 of 000 passed")
func _test_running_setup():
func _set_toolbutton_icon(btn, icon_name, text):
func _update_min_width():
func _open_script_in_editor(path, line_number):
	var r = load(path)
func _get_line_number_for_seq_search(search_strings, te):
	var result = null
	var line = Vector2i(0, 0)
	var s_flags = 0
	var i = 0
	var string_found = true
func _goto_code(path, line, method_name='', inner_class =''):
		var search_strings = []
func _goto_output(path, method_name, inner_class):
	var search_strings = [path]
	var line = _get_line_number_for_seq_search(search_strings, _output_control.get_rich_text_edit())
func _on_Collapse_pressed():
func _on_Expand_pressed():
func _on_CollapseAll_pressed():
func _on_ExpandAll_pressed():
func _on_Hide_Passing_pressed():
func _on_item_selected(script_path, inner_class, test_name, line):
func add_centered_text(t):
func clear_centered_text():
func clear():
func set_interface(which):
func collapse_all():
func expand_all():
func collapse_selected():
	var item = _ctrls.tree.get_selected()
func expand_selected():
	var item = _ctrls.tree.get_selected()
func set_show_orphans(should):
func set_font(font_name, size):
func set_output_control(value):
func load_json_results(j):
```

### `res:///addons/gut/gui/ShellOutOptions.gd`
```gdscript
extends ConfirmationDialog
const RUN_MODE_EDITOR = 'Editor'
const RUN_MODE_BLOCKING = 'Blocking'
const RUN_MODE_NON_BLOCKING = 'NonBlocking'
var GutEditorGlobals = load('res://addons/gut/gui/editor_globals.gd')
@onready var _bad_arg_dialog = $AcceptDialog
@onready var _main_container = $ScrollContainer/VBoxContainer
var _blurb_style_box = StyleBoxEmpty.new()
var _opt_maker_setup = false
var _arg_vbox : VBoxContainer = null
var _my_ok_button : Button = null
var _run_mode_theme = load('res://addons/gut/gui/EditorRadioButton.tres')
var _button_group = ButtonGroup.new()
var _btn_in_editor : Button = null
var _btn_blocking : Button = null
var _btn_non_blocking : Button = null
var _txt_additional_arguments = null
var _btn_godot_help = null
var _btn_gut_help = null
var opt_maker = null
var default_path = GutEditorGlobals.run_externally_options_path
var _config_file = ConfigFile.new()
var _run_mode = RUN_MODE_EDITOR
var run_mode = _run_mode:
var additional_arguments = '' :
func _debug_ready():
	var save_btn = Button.new()
	var load_btn = Button.new()
	var show_btn = Button.new()
func _ready():
func _validate_and_confirm():
		var dlg_text = str("Invalid arguments.  The following cannot be used:\n",
func _on_mode_button_pressed(which):
func _add_run_mode_button(text, desc_label, description):
	var btn = Button.new()
func _add_blurb(text):
	var ctrl = opt_maker.add_blurb(text)
func _add_title(text):
	var ctrl = opt_maker.add_title(text)
func _add_controls():
	var button_desc_box = HBoxContainer.new()
	var button_box = VBoxContainer.new()
	var button_desc = RichTextLabel.new()
func _show_help(help_method_name):
	var re = GutUtils.RunExternallyScene.instantiate()
	var text = await re.call(help_method_name)
func _save_to_config_file(f : ConfigFile):
func save_to_file(path = default_path):
func _load_from_config_file(f):
func load_from_file(path = default_path):
func reset():
func get_additional_arguments_array():
func should_run_externally():
var _invalid_args = [
var _invalid_blocking_args = [
func validate_arguments():
	var arg_array = get_additional_arguments_array()
	var i = 0
	var invalid_found = false
func get_godot_help():
```

### `res:///addons/gut/gui/ShortcutButton.gd`
```gdscript
extends Control
@onready var _ctrls = {
signal changed
signal start_edit
signal end_edit
const NO_SHORTCUT = '<None>'
var _source_event = InputEventKey.new()
var _pre_edit_event = null
var _key_disp = NO_SHORTCUT
var _editing = false
var _modifier_keys = [KEY_ALT, KEY_CTRL, KEY_META, KEY_SHIFT]
func _ready():
func _display_shortcut():
func _is_shift_only_modifier():
func _has_modifier(event):
func _is_modifier(keycode):
func _edit_mode(should):
func _unhandled_key_input(event):
func _on_SetButton_pressed():
func _on_SaveButton_pressed():
func _on_CancelButton_pressed():
func _on_ClearButton_pressed():
func to_s():
func is_valid():
func get_shortcut():
	var to_return = Shortcut.new()
func get_input_event():
func set_shortcut(sc):
func clear_shortcut():
func disable_set(should):
func disable_clear(should):
func cancel():
```

### `res:///addons/gut/gui/ShortcutDialog.gd`
```gdscript
extends ConfirmationDialog
var GutEditorGlobals = load('res://addons/gut/gui/editor_globals.gd')
var default_path = GutEditorGlobals.editor_shortcuts_path
@onready var scbtn_run_all = $Scroll/Layout/CRunAll/ShortcutButton
@onready var scbtn_run_current_script = $Scroll/Layout/CRunCurrentScript/ShortcutButton
@onready var scbtn_run_current_inner = $Scroll/Layout/CRunCurrentInner/ShortcutButton
@onready var scbtn_run_current_test = $Scroll/Layout/CRunCurrentTest/ShortcutButton
@onready var scbtn_run_at_cursor = $Scroll/Layout/CRunAtCursor/ShortcutButton
@onready var scbtn_rerun = $Scroll/Layout/CRerun/ShortcutButton
@onready var scbtn_panel = $Scroll/Layout/CPanelButton/ShortcutButton
@onready var scbtn_windowed = $Scroll/Layout/CToggleWindowed/ShortcutButton
@onready var all_buttons = [
func _debug_ready():
	var btn = Button.new()
func _ready():
func _cancel_all():
func _on_cancel():
func _on_edit_start(which):
func _on_edit_end():
func save_shortcuts():
func save_shortcuts_to_file(path):
	var f = ConfigFile.new()
func load_shortcuts():
func load_shortcuts_from_file(path):
	var f = ConfigFile.new()
	var empty = Shortcut.new()
```

### `res:///addons/gut/gui/about.gd`
```gdscript
extends AcceptDialog
var GutEditorGlobals = load('res://addons/gut/gui/editor_globals.gd')
var _bbcode = \
var _gut_links = [
var _vscode_links = [
var _donate_link = "https://buymeacoffee.com/bitwes"
@onready var _logo = $Logo
func _ready():
func _color_link(link_text):
func _link_table(entries):
	var text = ''
		var link = str("[url]", entry[1], "[/url]")
func _make_text():
	var gut_link_table = _link_table(_gut_links)
	var vscode_link_table = _link_table(_vscode_links)
	var text = _bbcode.format({
func _vert_center_logo():
func _on_rich_text_label_meta_clicked(meta: Variant) -> void:
func _on_mouse_entered() -> void:
func _on_mouse_exited() -> void:
var _odd_ball_eyes_l = 1.1
var _odd_ball_eyes_r = .7
func _on_rich_text_label_meta_hover_started(meta: Variant) -> void:
		var temp = _odd_ball_eyes_l
func _on_rich_text_label_meta_hover_ended(meta: Variant) -> void:
func _on_logo_pressed() -> void:
```

### `res:///addons/gut/gui/editor_globals.gd`
```gdscript
static func create_temp_directory():
static func is_being_edited_in_editor(which):
	var trav = which
	var is_scene_root = false
	var editor_root = which.get_tree().edited_scene_root
```

### `res:///addons/gut/gui/gut_config_gui.gd`
```gdscript
var PanelControls = load("res://addons/gut/gui/panel_controls.gd")
var GutConfig = load('res://addons/gut/gut_config.gd')
const DIRS_TO_LIST = 6
var _titles = {
var _cfg_ctrls = {}
var opt_maker = null
func _init(cont):
func _add_save_load():
	var ctrl = PanelControls.SaveLoadControl.new('Config', '', '')
func _on_save_path_chosen(path):
func _on_load_path_chosen(path):
func get_config_issues():
	var to_return = []
	var has_directory = false
		var key = str('directory_', i)
		var path = _cfg_ctrls[key].value
func clear():
func save_file(path):
	var gcfg = GutConfig.new()
func load_file(path):
	var gcfg = GutConfig.new()
var hide_this = null :
func set_options(opts):
	var options = opts.duplicate()
	var dirs_to_load = options.configured_dirs
		var value = ''
		var test_dir = opt_maker.add_directory(str('directory_', i), value, str(i))
func get_options(base_opts):
	var to_return = base_opts.duplicate()
	var fail_error_types = []
	var dirs = []
	var configured_dirs = []
		var key = str('directory_', i)
		var ctrl = _cfg_ctrls[key]
func mark_saved():
```

### `res:///addons/gut/gui/gut_gui.gd`
```gdscript
extends Control
var _gut = null
var _ctrls = {
var _title_mouse = {
signal switch_modes()
var _max_position = Vector2(100, 100)
func _ready():
func _process(_delta):
func get_display_size():
func _populate_ctrls():
func _get_first_child_named(obj_name, parent_obj):
	var kids = parent_obj.get_children()
	var index = 0
	var to_return = null
func _on_title_bar_input(event : InputEvent):
func _on_continue_pressed():
func _on_gut_start_run():
func _on_gut_end_run():
func _on_gut_start_script(script_obj):
func _on_gut_end_script():
func _on_gut_start_test(test_name):
func _on_gut_end_test():
func _on_gut_start_pause():
func _on_gut_end_pause():
func _on_switch_modes_pressed():
func _on_word_wrap_toggled(toggled):
func set_num_scripts(val):
func next_script(path, num_tests):
func next_test(__test_name):
func pause_before_teardown():
func set_gut(g):
func get_gut():
func get_textbox():
func set_elapsed_time(t):
func set_bg_color(c):
func set_title(text):
func to_top_left():
func to_bottom_right():
	var win_size = get_display_size()
func align_right():
	var win_size = get_display_size()
```

### `res:///addons/gut/gui/gut_logo.gd`
```gdscript
extends Node2D
	extends Node2D
	var _should_draw_laser = false
	var _laser_end_pos = Vector2.ZERO
	var _laser_timer : Timer = null
	var _color_tween : Tween
	var _size_tween : Tween
	var sprite : Sprite2D = null
	var default_position = Vector2(0, 0)
	var move_radius = 25
	var move_center = Vector2(0, 0)
	var default_color = Color(0.31, 0.31, 0.31)
	var _color = default_color :
	var color = _color :
	var default_size = 70
	var _size = default_size :
	var size = _size :
	func _init(node):
	func _ready():
	func _process(_delta):
	func _start_color_tween(old_color, new_color):
	func _start_size_tween(old_size, new_size):
	var _laser_size = 20.0
	func _draw() -> void:
			var end_pos = (_laser_end_pos - global_position) * 2
			var laser_size = _laser_size * (float(size)/float(default_size))
	func look_at_local_position(local_pos):
		var dir = position.direction_to(local_pos)
		var dist = position.distance_to(local_pos)
	func reset():
	func eye_laser(global_pos):
	func _stop_laser():
var GutEditorGlobals = load('res://addons/gut/gui/editor_globals.gd')
@export var active = false :
@export var disabled = false :
@onready var _reset_timer = $ResetTimer
@onready var _face_button = $FaceButton
@onready var left_eye : Eyeball = Eyeball.new($BaseLogo/LeftEye)
@onready var right_eye : Eyeball = Eyeball.new($BaseLogo/RightEye)
var _no_shine = load("res://addons/gut/images/GutIconV2_no_shine.png")
var _normal = load("res://addons/gut/images/GutIconV2_base.png")
var _is_in_edited_scene = false
signal pressed
func _debug_ready():
func _ready():
func _process(_delta):
func _on_reset_timer_timeout() -> void:
func _on_face_button_pressed() -> void:
func set_eye_scale(left, right=left):
func reset_eye_size():
func set_eye_color(left, right=left):
func reset_eye_color():
```

### `res:///addons/gut/gui/gut_user_preferences.gd`
```gdscript
	var gut_pref_prefix = 'gut/'
	var pname = '__not_set__'
	var default = null
	var value = '__not_set__'
	var _settings = null
	func _init(n, d, s):
	func _prefstr():
		var to_return = str(gut_pref_prefix, pname)
	func save_it():
	func load_it():
	func erase():
const EMPTY = '-- NOT_SET --'
var output_font_name = null
var output_font_size = null
var hide_result_tree = null
var hide_output_text = null
var hide_settings = null
var use_colors = null	# ? might be output panel
var run_externally = null
var run_externally_options_dialog_size = null
var shortcuts_dialog_size = null
var gut_window_size = null
var gut_window_on_top = null
func _init(editor_settings):
func save_it():
		var val = get(prop.name)
func load_it():
		var val = get(prop.name)
func erase_all():
		var val = get(prop.name)
```

### `res:///addons/gut/gui/option_maker.gd`
```gdscript
var PanelControls = load("res://addons/gut/gui/panel_controls.gd")
var _all_titles = []
var base_container = null
var controls = {}
func _init(cont):
func add_title(text):
	var row = PanelControls.BaseGutPanelControl.new(text, text)
func add_ctrl(key, ctrl):
func add_number(key, value, disp_text, v_min, v_max, hint=''):
	var ctrl = PanelControls.NumberControl.new(disp_text, value, v_min, v_max, hint)
func add_float(key, value, disp_text, step, v_min, v_max, hint=''):
	var ctrl = PanelControls.FloatControl.new(disp_text, value, step, v_min, v_max, hint)
func add_select(key, value, values, disp_text, hint=''):
	var ctrl = PanelControls.SelectControl.new(disp_text, value, values, hint)
func add_value(key, value, disp_text, hint=''):
	var ctrl = PanelControls.StringControl.new(disp_text, value, hint)
func add_multiline_text(key, value, disp_text, hint=''):
	var ctrl = PanelControls.MultiLineStringControl.new(disp_text, value, hint)
func add_boolean(key, value, disp_text, hint=''):
	var ctrl = PanelControls.BooleanControl.new(disp_text, value, hint)
func add_directory(key, value, disp_text, hint=''):
	var ctrl = PanelControls.DirectoryControl.new(disp_text, value, hint)
func add_file(key, value, disp_text, hint=''):
	var ctrl = PanelControls.DirectoryControl.new(disp_text, value, hint)
func add_save_file_anywhere(key, value, disp_text, hint=''):
	var ctrl = PanelControls.DirectoryControl.new(disp_text, value, hint)
func add_color(key, value, disp_text, hint=''):
	var ctrl = PanelControls.ColorControl.new(disp_text, value, hint)
var _blurbs = 0
func add_blurb(text):
	var ctrl = RichTextLabel.new()
func _on_title_cell_draw(which):
func clear():
```

### `res:///addons/gut/gui/panel_controls.gd`
```gdscript
	extends HBoxContainer
	var label = Label.new()
	var _lbl_unsaved = Label.new()
	var _lbl_invalid = Label.new()
	var value = null:
	signal changed
	func _init(title, val, hint=""):
	func mark_unsaved(is_it=true):
	func mark_invalid(is_it):
	func set_value(value):
	func get_value():
	extends BaseGutPanelControl
	var value_ctrl = SpinBox.new()
	func _init(title, val, v_min, v_max, hint=""):
	func _on_value_changed(new_value):
	func get_value():
	func set_value(val):
	extends NumberControl
	func _init(title, val, step, v_min, v_max, hint=""):
	extends BaseGutPanelControl
	var value_ctrl = LineEdit.new()
	func _init(title, val, hint=""):
	func _on_text_changed(new_value):
	func get_value():
	func set_value(val):
	extends BaseGutPanelControl
	var value_ctrl = TextEdit.new()
	func _init(title, val, hint=""):
		var vbox = VBoxContainer.new()
	func _on_text_changed(new_value):
	func get_value():
	func set_value(val):
	extends BaseGutPanelControl
	var value_ctrl = CheckBox.new()
	func _init(title, val, hint=""):
	func _on_button_toggled(new_value):
	func get_value():
	func set_value(val):
	extends BaseGutPanelControl
	var value_ctrl = OptionButton.new()
	var text = '' :
	func _init(title, val, choices, hint=""):
		var select_idx = 0
	func _on_item_selected(idx):
	func get_value():
	func set_value(val):
	extends BaseGutPanelControl
	var value_ctrl = ColorPickerButton.new()
	func _init(title, val, hint=""):
	func get_value():
	func set_value(val):
	extends BaseGutPanelControl
	var value_ctrl := LineEdit.new()
	var dialog := FileDialog.new()
	var enabled_button = CheckButton.new()
	var _btn_dir := Button.new()
	func _init(title, val, hint=""):
	func _update_display():
		var is_empty = value_ctrl.text == ''
	func _ready():
	func _on_value_changed(new_text):
	func _on_selected(path):
	func _on_dir_button_pressed():
	func get_value():
	func set_value(val):
	extends FileDialog
	var show_diretory_types = true :
	var show_res = true :
	var show_user = true :
	var show_os = true :
	var _dir_type_hbox = null
	var _btn_res = null
	var _btn_user = null
	var _btn_os = null
	func _ready():
	func _init_controls():
		var spacer1 = CenterContainer.new()
		var spacer2 = spacer1.duplicate()
	func _update_display():
	extends BaseGutPanelControl
	var btn_load = Button.new()
	var btn_save = Button.new()
	var dlg_load := FileDialogSuperPlus.new()
	var dlg_save := FileDialogSuperPlus.new()
	signal save_path_chosen(path)
	signal load_path_chosen(path)
	func _init(title, val, hint):
	func _ready():
	func _on_load_selected(path):
	func _on_save_selected(path):
	func _on_load_pressed():
	func _on_save_pressed():
```

### `res:///addons/gut/gui/run_from_editor.gd`
```gdscript
extends Node2D
var GutLoader : Object
func _init() -> void:
func _ready() -> void:
	var runner : Node = load("res://addons/gut/gui/GutRunner.tscn").instantiate()
```

### `res:///addons/gut/gut.gd`
```gdscript
extends 'res://addons/gut/gut_to_move.gd'
class_name GutMain
const LOG_LEVEL_FAIL_ONLY = 0
const LOG_LEVEL_TEST_AND_FAILURES = 1
const LOG_LEVEL_ALL_ASSERTS = 2
const WAITING_MESSAGE = '/# waiting #/'
const PAUSE_MESSAGE = '/# Pausing.  Press continue button...#/'
const COMPLETED = 'completed'
signal start_pause_before_teardown
signal end_pause_before_teardown
signal start_run
signal end_run
signal start_script(test_script_obj)
signal end_script
signal start_test(test_name)
signal end_test
var _inner_class_name = ''
var inner_class_name = _inner_class_name :
var _ignore_pause_before_teardown = false
var ignore_pause_before_teardown = _ignore_pause_before_teardown :
var _log_level = 1
var log_level = _log_level:
var wait_log_delay = 0.5
var _disable_strict_datatype_checks = false
var disable_strict_datatype_checks = false :
var _export_path = ''
var export_path = '' :
var _include_subdirectories = false
var include_subdirectories = _include_subdirectories :
var _double_strategy = GutUtils.DOUBLE_STRATEGY.SCRIPT_ONLY
var double_strategy = _double_strategy  :
var _pre_run_script = ''
var pre_run_script = _pre_run_script :
var _post_run_script = ''
var post_run_script = _post_run_script :
var _color_output = false
var color_output = false :
var _junit_xml_file = ''
var junit_xml_file = '' :
var _junit_xml_timestamp = false
var junit_xml_timestamp = false :
var paint_after = .1:
var _unit_test_name = ''
var unit_test_name = _unit_test_name :
var _parameter_handler = null
var parameter_handler = _parameter_handler :
var _lgr = GutUtils.get_logger()
var logger = _lgr :
var error_tracker = GutUtils.get_error_tracker()
var _add_children_to = self
var add_children_to = self :
var _test_collector = GutUtils.TestCollector.new()
func get_test_collector():
func get_version():
var _orphan_counter =  GutUtils.OrphanCounter.new()
func get_orphan_counter():
func get_autofree():
var _stubber = GutUtils.Stubber.new()
func get_stubber():
var _doubler = GutUtils.Doubler.new()
func get_doubler():
var _spy = GutUtils.Spy.new()
func get_spy():
var _is_running = false
func is_running():
var  _should_print_versions = true # used to cut down on output in tests.
var _should_print_summary = true
var _file_prefix = 'test_'
var _inner_class_prefix = 'Test'
var _select_script = ''
var _last_paint_time = 0.0
var _strutils = GutUtils.Strutils.new()
var _pre_run_script_instance = null
var _post_run_script_instance = null
var _script_name = null
var _test_script_objects = []
var _waiting = false
var _start_time = 0.0
var _current_test = null
var _pause_before_teardown = false
var _cancel_import = false
var _auto_queue_free_delay = .1
func _init(override_logger=null):
func update_loggers():
func _ready():
func _notification(what):
func _print_versions(send_all = true):
	var info = GutUtils.version_numbers.get_version_text()
func _set_log_level(level):
func end_teardown_pause():
func _log_test_children_warning(test_script):
	var kids = test_script.get_children()
		var msg = ''
func _log_end_run():
	var summary = GutUtils.Summary.new(self)
func _validate_hook_script(path):
	var result = {
		var inst = load(path).new()
func _run_hook_script(inst):
func _init_run():
	var valid = true
	var pre_hook_result = _validate_hook_script(_pre_run_script)
	var post_hook_result = _validate_hook_script(_post_run_script)
func _end_run():
func _export_results():
func _export_junit_xml():
	var exporter = GutUtils.JunitXmlExport.new()
	var output_file = _junit_xml_file
		var ext = "." + output_file.get_extension()
	var f_result = exporter.write_file(self, output_file)
func _print_script_heading(coll_script):
func _does_class_name_match(the_class_name, script_class_name):
func _create_script_instance(collected_script):
	var test_script = collected_script.get_new()
func _wait_for_continue_button():
func _get_indexes_matching_script_name(script_name):
	var indexes = [] # empty runs all
func _get_indexes_matching_path(path):
	var indexes = []
func _run_parameterized_test(test_script, test_name):
		var index = 1
			var cur_assert_count = _current_test.assert_count
func _run_test(script_inst, test_name, param_index = -1):
	var test_id = str(script_inst.collected_script.get_filename_and_inner(), ':', test_name)
	var aqf_count = _orphan_counter.autofree.get_queue_free_count()
func get_current_test_orphans():
	var sname = get_current_test_object().collected_script.get_ref().get_filename_and_inner()
	var tname = get_current_test_object().name
func _call_before_all(test_script, collected_script):
	var before_all_test_obj = GutUtils.CollectedTest.new()
func _call_after_all(test_script, collected_script):
	var after_all_test_obj = GutUtils.CollectedTest.new()
func _should_skip_script(test_script, collected_script):
	var skip_message = 'not skipped'
	var skip_value = test_script.get('skip_script')
	var should_skip = false
		var msg = str('- [Script skipped]:  ', skip_message)
func _test_the_scripts(indexes=[]):
	var is_valid = _init_run()
	var indexes_to_run = []
		var coll_script = _test_collector.scripts[indexes_to_run[test_indexes]]
		var test_script = _create_script_instance(coll_script)
				var ticks_before := Time.get_ticks_usec()
					var now = Time.get_ticks_msec()
					var time_since = (now - _last_paint_time) / 1000.0
			var script_sum = str(coll_script.get_passing_test_count(), '/', coll_script.get_ran_test_count(), ' passed.')
func _pass(text=''):
func get_call_count_text():
	var to_return = ''
func _fail(text=''):
		var line_number = _extract_line_number(_current_test)
		var line_text = '  at line ' + str(line_number)
		var call_count_text = get_call_count_text()
func _pending(text=''):
func _extract_line_number(current_test):
	var line_number = -1
	var stackTrace = get_stack()
			var line = stackTrace[index]
			var function = line.get("function")
func _get_files(path, prefix, suffix):
	var files = []
	var directories = []
	var d = DirAccess.open(path)
	var fs_item = d.get_next()
	var full_path = ''
		var dir_files = _get_files(directories[dir], prefix, suffix)
func get_elapsed_time() -> float:
	var to_return = 0.0
func p(text, level=0):
	var str_text = str(text)
func test_scripts(_run_rest=false):
		var indexes = _get_indexes_matching_script_name(_script_name)
func run_tests(run_rest=false):
func add_script(script):
func add_directory(path, prefix=_file_prefix, suffix=".gd"):
	var dir = DirAccess.open(path)
		var files = _get_files(path, prefix, suffix)
func select_script(script_name):
func export_tests(path=_export_path):
		var result = _test_collector.export_tests(path)
func import_tests(path=_export_path):
		var result = _test_collector.import_tests(path)
func import_tests_if_none_found():
func export_if_tests_found():
func maximize():
func clear_text():
func get_test_count():
func get_assert_count():
func get_pass_count():
func get_fail_count():
func get_pending_count():
func pause_before_teardown():
func get_current_script_object():
	var to_return = null
func get_current_test_object():
func get_summary():
func get_pre_run_script_instance():
func get_post_run_script_instance():
func show_orphans(should):
func get_logger():
func get_test_script_count():
```

### `res:///addons/gut/gut_cmdln.gd`
```gdscript
extends SceneTree
var VersionConversion = load("res://addons/gut/version_conversion.gd")
func _init() -> void:
	var max_iter := 20
	var iter := 0
	var Loader : Object = load("res://addons/gut/gut_loader.gd")
	var cli : Node = load('res://addons/gut/cli/gut_cli.gd').new()
```

### `res:///addons/gut/gut_config.gd`
```gdscript
const FAIL_ERROR_TYPE_ENGINE = &'engine'
const FAIL_ERROR_TYPE_PUSH_ERROR = &'push_error'
const FAIL_ERROR_TYPE_GUT = &'gut'
var valid_fonts = GutUtils.gut_fonts.get_font_names()
var _deprecated_values = {
var default_options = {
var options = default_options.duplicate()
var logger = GutUtils.get_logger()
func _null_copy(h):
	var new_hash = {}
func _load_options_from_config_file(file_path, into):
	var f = FileAccess.open(file_path, FileAccess.READ)
		var result = FileAccess.get_open_error()
	var json = f.get_as_text()
	var test_json_conv = JSON.new()
	var results = test_json_conv.get_data()
func _load_dict_into(source, dest):
func _apply_options(opts, gut):
func write_options(path):
	var content = JSON.stringify(options, ' ')
	var f = FileAccess.open(path, FileAccess.WRITE)
	var result = FileAccess.get_open_error()
func save_file(path):
func load_options(path):
func load_file(path):
func load_options_no_defaults(path):
func apply_options(gut):
```

### `res:///addons/gut/gut_fonts.gd`
```gdscript
const DEFAULT_CUSTOM_FONT_NAME = 'CourierPrime'
const THEME_FONT_TO_FONT_TYPES_MAP = {
const FONT_TYPES = {
var fonts = {
var custom_font_path = 'res://addons/gut/fonts/'
func _init():
func _populate_default_fonts():
	var ctrl = TextEdit.new()
	var f = ctrl.get_theme_font('font')
func _load_font(font_name, font_type, font_path):
	var dynamic_font = FontFile.new()
func get_font(font_name, font_type='Regular'):
		var filename = custom_font_path.path_join(str(font_name, '-', font_type, '.ttf'))
func get_font_names():
func get_font_for_theme_font_name(theme_font_name, custom_font_name):
```

### `res:///addons/gut/gut_loader.gd`
```gdscript
const WARNING_PATH : String = 'debug/gdscript/warnings/'
static func _static_init() -> void:
	var WarningsManager = load('res://addons/gut/warnings_manager.gd')
	var _utils : Object = load('res://addons/gut/utils.gd')
static func restore_ignore_addons() -> void:
```

### `res:///addons/gut/gut_menu.gd`
```gdscript
var sub_menu : PopupMenu = null
var _menus = {
signal about
signal rerun
signal run_all
signal run_at_cursor
signal run_inner_class
signal run_script
signal run_test
signal show_gut
signal toggle_windowed
func _init():
func _invalid_index():
func _on_sub_menu_index_pressed(index):
	var to_call : Callable = _invalid_index
func add_menu(display_text, sig_to_emit, tooltip=''):
	var index = sub_menu.item_count
func make_menu():
func set_shortcut(menu_name, accel_or_input_key):
func disable_menu(menu_name, disabled):
func apply_gut_shortcuts(shortcut_dialog):
```

### `res:///addons/gut/gut_plugin.gd`
```gdscript
extends EditorPlugin
var VersionConversion = load("res://addons/gut/version_conversion.gd")
var MenuManager = load("res://addons/gut/gut_menu.gd")
var GutWindow = load("res://addons/gut/gui/GutEditorWindow.tscn")
var BottomPanelScene = preload('res://addons/gut/gui/GutBottomPanel.tscn')
var GutEditorGlobals = load('res://addons/gut/gui/editor_globals.gd')
var _bottom_panel : Control = null
var _menu_mgr = null
var _gut_button = null
var _gut_window = null
var _dock_mode = 'none'
func _init():
func _enter_tree():
func _version_conversion():
	var EditorGlobals = load("res://addons/gut/gui/editor_globals.gd")
func gut_as_window():
func gut_as_panel():
func toggle_windowed():
func _deparent_bottom_panel():
func _exit_tree():
func show_output_panel():
	var panel = null
	var kids = _bottom_panel.get_parent().get_children()
	var idx = 0
```

### `res:///addons/gut/gut_to_move.gd`
```gdscript
extends Node
func directory_delete_files(path):
	var d = DirAccess.open(path)
	var thing = d.get_next() # could be a dir or a file or something else maybe?
	var full_path = ''
func file_delete(path):
	var d = DirAccess.open(path.get_base_dir())
func is_file_empty(path):
	var f = FileAccess.open(path, FileAccess.READ)
	var result = FileAccess.get_open_error()
	var empty = true
func get_file_as_text(path):
func file_touch(path):
func simulate(obj, times, delta, check_is_processing: bool = false):
```

### `res:///addons/gut/gut_tracked_error.gd`
```gdscript
class_name GutTrackedError
var backtrace = []
var code = GutUtils.NO_TEST
var rationale = GutUtils.NO_TEST
var error_type = -1
var editor_notify = false
var file = GutUtils.NO_TEST
var function = GutUtils.NO_TEST
var line = -1
var handled = false
func to_s() -> String:
func is_push_error():
func is_engine_error():
func is_gut_error():
func contains_text(text):
func get_error_type_name():
	var to_return = "Unknown"
```

### `res:///addons/gut/gut_vscode_debugger.gd`
```gdscript
extends 'res://addons/gut/gut_cmdln.gd'
func run_tests(runner):
```

### `res:///addons/gut/hook_script.gd`
```gdscript
class_name GutHookScript
var JunitXmlExport = load('res://addons/gut/junit_xml_export.gd')
var gut  = null
var _exit_code = null
var _should_abort =  false
func run():
func set_exit_code(code : int):
func get_exit_code():
func abort():
func should_abort():
```

### `res:///addons/gut/inner_class_registry.gd`
```gdscript
var _registry = {}
func _create_reg_entry(base_path, subpath):
	var to_return = {
func _register_inners(base_path, obj, prev_inner = ''):
	var const_map = obj.get_script_constant_map()
	var consts = const_map.keys()
	var const_idx = 0
		var key = consts[const_idx]
		var thing = const_map[key]
			var cur_inner = str(prev_inner, ".", key)
		const_idx += 1
func register(base_script):
	var base_path = base_script.resource_path
func get_extends_path(inner_class):
func get_subpath(inner_class):
func get_base_path(inner_class):
func has(inner_class):
func get_base_resource(inner_class):
func to_s():
	var text = ""
```

### `res:///addons/gut/input_factory.gd`
```gdscript
class_name GutInputFactory
static func _to_scancode(which):
	var key_code = which
static func new_mouse_button_event(position, global_position, pressed, button_index) -> InputEventMouseButton:
	var event = InputEventMouseButton.new()
static func key_up(which) -> InputEventKey:
	var event = InputEventKey.new()
static func key_down(which) -> InputEventKey:
	var event = InputEventKey.new()
static func action_up(which, strength=1.0) -> InputEventAction:
	var event  = InputEventAction.new()
static func action_down(which, strength=1.0) -> InputEventAction:
	var event  = InputEventAction.new()
static func mouse_left_button_down(position, global_position=null) -> InputEventMouseButton:
	var event = new_mouse_button_event(position, global_position, true, MOUSE_BUTTON_LEFT)
static func mouse_left_button_up(position, global_position=null) -> InputEventMouseButton:
	var event = new_mouse_button_event(position, global_position, false, MOUSE_BUTTON_LEFT)
static func mouse_double_click(position, global_position=null) -> InputEventMouseButton:
	var event = new_mouse_button_event(position, global_position, false, MOUSE_BUTTON_LEFT)
static func mouse_right_button_down(position, global_position=null) -> InputEventMouseButton:
	var event = new_mouse_button_event(position, global_position, true, MOUSE_BUTTON_RIGHT)
static func mouse_right_button_up(position, global_position=null) -> InputEventMouseButton:
	var event = new_mouse_button_event(position, global_position, false, MOUSE_BUTTON_RIGHT)
static func mouse_motion(position, global_position=null) -> InputEventMouseMotion:
	var event = InputEventMouseMotion.new()
static func mouse_relative_motion(offset, last_motion_event=null, speed=Vector2(0, 0)) -> InputEventMouseMotion:
	var event = null
```

### `res:///addons/gut/input_sender.gd`
```gdscript
class_name GutInputSender
	extends Node
	var events = []
	var time_delay = null
	var frame_delay = null
	var _waited_frames = 0
	var _is_ready = false
	var _delay_started = false
	signal event_ready
	func _physics_process(delta):
	func _init(t_delay,f_delay):
	func _on_time_timeout():
	func _delay_timer(t):
	func is_ready():
	func start():
			var t = _delay_timer(time_delay)
	extends Node2D
	var down_color = Color(1, 1, 1, .25)
	var up_color = Color(0, 0, 0, .25)
	var line_color = Color(1, 0, 0)
	var disabled = true :
	var _draw_at = Vector2(0, 0)
	var _b1_down = false
	var _b2_down = false
	func draw_event(event):
	func _draw_cicled_cursor():
		var r = 10
		var b1_color = up_color
		var b2_color = up_color
			var pos = _draw_at - (Vector2(r * 1.5, 0))
			var pos = _draw_at + (Vector2(r * 1.5, 0))
	func _draw_square_cursor():
		var r = 10
		var b1_color = up_color
		var b2_color = up_color
		var blen = r * .75
	func _draw():
const INPUT_WARN = 'If using Input as a reciever it will not respond to *_down events until a *_up event is recieved.  Call the appropriate *_up event or use hold_for(...) to automatically release after some duration.'
var _lgr = GutUtils.get_logger()
var _receivers = []
var _input_queue = []
var _next_queue_item = null
var _last_event = null
var _pressed_keys = {}
var _pressed_actions = {}
var _pressed_mouse_buttons = {}
var _auto_flush_input = false
var _tree_items_parent = null
var _mouse_draw = null;
var _default_mouse_position = {
var _last_mouse_position = {
var mouse_warp = false
var draw_mouse = true
signal idle
func _init(r=null):
func _notification(what):
func _add_queue_item(item):
func _handle_pressed_keys(event):
func _handle_mouse_position(event):
func _send_event(event):
func _send_or_record_event(event):
func _set_last_mouse_positions(event : InputEventMouse):
func _apply_last_position_and_set_last_position(event, position, global_position):
func _new_defaulted_mouse_button_event(position, global_position):
	var event = InputEventMouseButton.new()
func _new_defaulted_mouse_motion_event(position, global_position):
	var event = InputEventMouseMotion.new()
func _on_queue_item_ready(item):
	var done_event = _input_queue.pop_front()
func add_receiver(obj):
func get_receivers():
func is_idle():
func is_key_pressed(which):
	var event = GutInputFactory.key_up(which)
func is_action_pressed(which):
func is_mouse_button_pressed(which):
func get_auto_flush_input():
func set_auto_flush_input(val):
func wait(t):
		var suffix = t.substr(t.length() -1, 1)
		var val = t.rstrip('s').rstrip('f').to_float()
func clear():
func key_up(which):
	var event = GutInputFactory.key_up(which)
func key_down(which):
	var event = GutInputFactory.key_down(which)
func key_echo():
		var new_key = _last_event.duplicate()
func action_up(which, strength=1.0):
	var event  = GutInputFactory.action_up(which, strength)
func action_down(which, strength=1.0):
	var event  = GutInputFactory.action_down(which, strength)
func mouse_left_button_down(position=null, global_position=null):
	var event = _new_defaulted_mouse_button_event(position, global_position)
func mouse_left_button_up(position=null, global_position=null):
	var event = _new_defaulted_mouse_button_event(position, global_position)
func mouse_double_click(position=null, global_position=null):
	var event = GutInputFactory.mouse_double_click(position, global_position)
func mouse_right_button_down(position=null, global_position=null):
	var event = _new_defaulted_mouse_button_event(position, global_position)
func mouse_right_button_up(position=null, global_position=null):
	var event = _new_defaulted_mouse_button_event(position, global_position)
func mouse_motion(position, global_position=null):
	var event = _new_defaulted_mouse_motion_event(position, global_position)
func mouse_relative_motion(offset, speed=Vector2(0, 0)):
	var last_event = _new_defaulted_mouse_motion_event(null, null)
	var event = GutInputFactory.mouse_relative_motion(offset, last_event, speed)
func mouse_set_position(position, global_position=null):
	var event = _new_defaulted_mouse_motion_event(position, global_position)
func mouse_left_click_at(where, duration = '5f'):
func send_event(event):
func release_all():
		var event = _pressed_mouse_buttons[key].duplicate()
func wait_frames(num_frames):
	var item = InputQueueItem.new(0, num_frames)
func wait_secs(num_secs):
	var item = InputQueueItem.new(num_secs, 0)
func hold_for(duration):
		var next_event = _last_event.duplicate()
func hold_frames(duration:int):
func hold_seconds(duration:float):
```

### `res:///addons/gut/junit_xml_export.gd`
```gdscript
var _exporter = GutUtils.ResultExporter.new()
func indent(s, ind):
	var to_return = ind + s
func wrap_cdata(content):
func add_attr(name, value):
func _export_test_result(test):
	var to_return = ''
		var skip_tag = str("<skipped message=\"pending\">", wrap_cdata(test.pending[0]), "</skipped>")
		var fail_tag = str("<failure message=\"failed\">", wrap_cdata(test.failing[0]), "</failure>")
func _export_tests(script_result, classname):
	var to_return = ""
		var test = script_result[key]
		var assert_count = test.passing.size() + test.failing.size()
func _sum_test_time(script_result, classname)->float:
	var to_return := 0.0
		var test = script_result[key]
func _export_scripts(exp_results):
	var to_return = ""
		var s = exp_results.test_scripts.scripts[key]
func get_results_xml(gut):
	var exp_results = _exporter.get_results_dictionary(gut)
	var to_return = '<?xml version="1.0" encoding="UTF-8"?>' + "\n"
func write_file(gut, path):
	var xml = get_results_xml(gut)
	var f_result = GutUtils.write_file(path, xml)
		var msg = str("Error:  ", f_result, ".  Could not create export file ", path)
```

### `res:///addons/gut/lazy_loader.gd`
```gdscript
static func load_all():
static func print_usage():
static func clear():
var _loaded = null
var _path = null
func _init(path):
func get_loaded():
```

### `res:///addons/gut/logger.gd`
```gdscript
var types = {
var fmts = {
var _type_data = {
var _logs = {
var _printers = {
var _gut = null
var _indent_level = 0
var _min_indent_level = 0
var _indent_string = '    '
var _less_test_names = false
var _yield_calls = 0
var _last_yield_text = ''
func _init():
func _indent_text(text):
	var to_return = text
	var ending_newline = ''
	var pad = get_indent()
func _should_print_to_printer(key_name):
func _print_test_name():
	var cur_test = _gut.get_current_test_object()
		var param_text = ''
func _output(text, fmt=null):
func _log(text, fmt=fmts.none):
	var indented = _indent_text(text)
func get_warnings():
func get_errors():
func get_infos():
func get_debugs():
func get_deprecated():
func get_count(log_type=null):
	var count = 0
func get_log_entries(log_type):
func get_indent():
	var pad = ''
func _output_type(type, text):
	var td = _type_data[type]
		var start = str('[', td.disp, ']')
		var indented_start = _indent_text(start)
		var indented_end = _indent_text(text)
func _output_type_no_indent(type, text):
	var td = _type_data[type]
		var start = str('[', td.disp, ']')
func debug(text):
func deprecated(text, alt_method=null):
	var msg = text
func error(text):
func expected_error(text):
func failed(text):
func info(text):
func orphan(text):
	var td = _type_data["orphan"]
func passed(text):
func pending(text):
func risky(text):
func warn(text):
func log(text='', fmt=fmts.none):
func lograw(text, fmt=fmts.none):
func log_test_name():
func get_gut():
func set_gut(gut):
func get_indent_level():
func set_indent_level(indent_level):
func get_indent_string():
func set_indent_string(indent_string):
func clear():
func inc_indent():
func dec_indent():
func is_type_enabled(type):
func set_type_enabled(type, is_enabled):
func get_less_test_names():
func set_less_test_names(less_test_names):
func disable_printer(name, is_disabled):
func is_printer_disabled(name):
func disable_formatting(is_disabled):
func disable_all_printers(is_disabled):
func get_printer(printer_key):
func _yield_text_terminal(text):
	var printer = _printers['terminal']
func wait_msg(text):
func get_gui_bbcode():
```

### `res:///addons/gut/method_maker.gd`
```gdscript
	var p_name = null
	var default = null
	var vararg = false
	func _init(n,d):
	func get_signature():
var _lgr = GutUtils.get_logger()
const PARAM_PREFIX = 'p_'
var _supported_defaults = []
func _init():
var _func_text = GutUtils.get_file_as_text('res://addons/gut/double_templates/function_template.txt')
var _init_text = GutUtils.get_file_as_text('res://addons/gut/double_templates/init_template.txt')
func _is_supported_default(type_flag):
func _make_stub_default(method, index):
func _make_arg_array(method_meta):
	var to_return = []
	var has_unsupported_defaults = false
		var pname = method_meta.args[i].name
		var dflt_text = _make_stub_default(method_meta.name, i)
		var cp = CallParameters.new("args", "")
func _get_arg_text(arg_array):
	var text = ''
func _get_super_call_text(method_name, args):
	var params = ''
func _get_spy_call_parameters_text(args):
	var called_with = 'null'
func _get_init_text(meta, args, method_params, param_array):
	var text = null
	var decleration = str('func ', meta.name, '(', method_params, ')')
	var super_params = ''
func get_function_text(meta, override_size=null):
	var method_params = ''
	var text = null
	var result = _make_arg_array(meta)
	var has_unsupported = result[0]
	var args = result[1]
	var param_array = _get_spy_call_parameters_text(args)
			var decleration = str('func ', meta.name, '(', method_params, '):')
func get_logger():
func set_logger(logger):
```

### `res:///addons/gut/one_to_many.gd`
```gdscript
var items = {}
func size(one=null):
	var to_return = 0
func add(one, many_item):
func clear():
func has(one, many_item):
	var to_return = false
func to_s():
	var to_return = ''
```

### `res:///addons/gut/orphan_counter.gd`
```gdscript
	const UNGROUPED = "Outside Tests"
	const SUBGROUP_SEP = '->'
	var orphan_ids = {}
	var oprhans_by_group = {}
	var strutils = GutUtils.Strutils.new()
	func _get_system_orphan_node_ids():
	func _make_group_key(group=null, subgroup=null):
		var to_return = UNGROUPED
	func _add_orphan_by_group(id, group, subgroup):
		var key = _make_group_key(group, subgroup)
	func process_orphans(group=null, subgroup=null):
		var new_orphans = []
	func get_orphan_ids(group=null, subgroup=null):
		var key = _make_group_key(group, subgroup)
	func get_all_group_orphans(group):
		var to_return = []
	func clean():
			var inst = orphan_ids[key].instance
var _strutils = GutStringUtils.new()
var orphanage : Orphanage = Orphanage.new()
var logger = GutUtils.get_logger()
var autofree = GutUtils.AutoFree.new()
func _count_all_children(instance):
	var count = instance.get_child_count()
func get_orphan_list_text(orphan_ids):
	var text = ""
		var kid_count_text = ''
		var inst = orphanage.orphan_ids[id].instance
			var kid_count = _count_all_children(inst)
			var autofree_text = ''
func orphan_count() -> int:
func record_orphans(group, subgroup = null):
func convert_instance_ids_to_valid_instances(instance_ids):
	var to_return = []
func end_script(script_path, should_log):
	var orphans = orphanage.get_all_group_orphans(script_path)
func end_test(script_path, test_name, should_log = true):
	var orphans = get_orphan_ids(script_path, test_name)
func get_orphan_ids(group=null, subgroup=null):
	var ids = []
func get_count() -> int:
func log_all():
	var last_script = ''
	var last_test = ''
		var entry = orphanage.orphan_ids[id]
			var orphan_ids = orphanage.get_orphan_ids(last_script, last_test)
```

### `res:///addons/gut/parameter_factory.gd`
```gdscript
static func named_parameters(names, values):
	var named = []
		var entry = {}
		var parray = values[i]
```

### `res:///addons/gut/parameter_handler.gd`
```gdscript
var _params = null
var _call_count = 0
var _logger = null
func _init(params=null):
func next_parameters():
func get_current_parameters():
func is_done():
	var done = true
func get_logger():
func set_logger(logger):
func get_call_count():
func get_parameter_count():
```

### `res:///addons/gut/printers.gd`
```gdscript
	var _format_enabled = true
	var _disabled = false
	var _printer_name = 'NOT SET'
	var _show_name = false # used for debugging, set manually
	func get_format_enabled():
	func set_format_enabled(format_enabled):
	func send(text, fmt=null):
		var formatted = text
	func get_disabled():
	func set_disabled(disabled):
	func _output(text):
	func format_text(text, fmt):
	extends Printer
	var _textbox = null
	var _colors = {
	func _init():
	func _wrap_with_tag(text, tag):
	func _color_text(text, c_word):
	func format_text(text, fmt):
	func _output(text):
	func get_textbox():
	func set_textbox(textbox):
	func clear_line():
	func get_bbcode():
	func get_disabled():
	extends Printer
	var _buffer = ''
	func _init():
	func _output(text):
	extends Printer
	var escape = PackedByteArray([0x1b]).get_string_from_ascii()
	var cmd_colors  = {
	func _init():
	func _output(text):
	func format_text(text, fmt):
	func clear_line():
	func back(n):
	func forward(n):
```

### `res:///addons/gut/result_exporter.gd`
```gdscript
var json = JSON.new()
var strutils = GutStringUtils.new()
func _export_tests(gut, collected_script):
	var to_return = {}
	var tests = collected_script.tests
			var orphans = gut.get_orphan_counter().get_orphan_ids(
			var orphan_node_strings = []
func _export_scripts(gut):
	var collector = gut.get_test_collector()
	var scripts = {}
		var test_data = _export_tests(gut, s)
func _make_results_dict():
	var result =  {
func get_results_dictionary(gut, include_scripts=true):
	var scripts = []
	var result =  _make_results_dict()
	var totals = gut.get_summary().get_totals()
	var props = result.test_scripts.props
func write_json_file(gut, path):
	var dict = get_results_dictionary(gut)
	var json_text = JSON.stringify(dict, ' ')
	var f_result = GutUtils.write_file(path, json_text)
		var msg = str("Error:  ", f_result, ".  Could not create export file ", path)
func write_summary_file(gut, path):
	var dict = get_results_dictionary(gut, false)
	var json_text = JSON.stringify(dict, ' ')
	var f_result = GutUtils.write_file(path, json_text)
		var msg = str("Error:  ", f_result, ".  Could not create export file ", path)
```

### `res:///addons/gut/script_parser.gd`
```gdscript
const BLACKLIST = [
	const NO_DEFAULT = '__no__default__'
	var _meta = {}
	var meta = _meta :
	var is_local = false
	var _parameters = []
	func _init(metadata):
		var start_default = _meta.args.size() - _meta.default_args.size()
			var arg = _meta.args[i]
	func is_eligible_for_doubling():
		var has_bad_flag = _meta.flags & \
	func is_accessor():
	func to_s():
		var s = _meta.name + "("
			var arg = _meta.args[i]
				var val = str(arg.default)
	var _methods_by_name = {}
	var _script_path = null
	var script_path = _script_path :
	var _subpath = null
	var subpath = null :
	var _resource = null
	var resource = null :
	var _is_native = false
	var is_native = _is_native:
	var _native_methods = {}
	var _native_class_name = ""
	func _init(script_or_inst, inner_class=null):
		var to_load = script_or_inst
			var inst = to_load.new()
	func _print_flags(meta):
	func _get_native_methods(base_type):
		var to_return = []
			var source = str('extends ', base_type)
			var inst = GutUtils.create_script_from_source(source).new()
	func _parse_methods(thing):
		var methods = []
			var base_type = thing.get_instance_base_type()
			var parsed = ParsedMethod.new(m)
				var parsed_method = ParsedMethod.new(m)
	func _find_subpath(parent_script, inner):
		var const_map = parent_script.get_script_constant_map()
		var consts = const_map.keys()
		var const_idx = 0
		var found = false
		var to_return = null
			var key = consts[const_idx]
			var const_val = const_map[key]
			const_idx += 1
	func get_method(name):
	func get_super_method(name):
		var to_return = get_method(name)
	func get_local_method(name):
		var to_return = get_method(name)
	func get_sorted_method_names():
		var keys = _methods_by_name.keys()
	func get_local_method_names():
		var names = []
	func get_super_method_names():
		var names = []
	func get_local_methods():
		var to_return = []
			var method = _methods_by_name[key]
	func get_super_methods():
		var to_return = []
			var method = _methods_by_name[key]
	func get_extends_text():
		var text = null
var scripts = {}
func _get_instance_id(thing):
	var inst_id = null
		var id_str = str(thing).replace("<", '').replace(">", '').split('#')[1]
func parse(thing, inner_thing=null):
	var key = -1
	var parsed = null
			var obj = instance_from_id(_get_instance_id(thing))
			var inner = null
```

### `res:///addons/gut/signal_watcher.gd`
```gdscript
const ARG_NOT_SET = '_*_argument_*_is_*_not_set_*_'
var _watched_signals = {}
var _lgr = GutUtils.get_logger()
func _add_watched_signal(obj, name):
func _on_watched_signal(arg1=ARG_NOT_SET, arg2=ARG_NOT_SET, arg3=ARG_NOT_SET, \
	var args = [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11]
	var idx = args.size() -1
	var signal_name = args[args.size() -1]
	var object = args[args.size() -1]
func _obj_name_pair(obj_or_signal, signal_name=null):
	var to_return = {
func does_object_have_signal(object, signal_name):
	var signals = object.get_signal_list()
func watch_signals(object):
	var signals = object.get_signal_list()
func watch_signal(object, signal_name):
	var did = false
func get_emit_count(object, signal_name):
	var to_return = -1
func did_emit(object, signal_name=null):
	var vals = _obj_name_pair(object, signal_name)
	var did = false
func print_object_signals(object):
	var list = object.get_signal_list()
func get_signal_parameters(object, signal_name, index=-1):
	var params = null
		var all_params = _watched_signals[object][signal_name]
func is_watching_object(object):
func is_watching(object, signal_name):
func clear():
func get_signals_emitted(obj):
	var emitted = []
func get_signal_summary(obj):
	var emitted = {}
				var entry = {
func print_signal_summary(obj):
		var msg = str('Not watching signals for ', obj)
	var summary = get_signal_summary(obj)
	var sorted = summary.keys()
```

### `res:///addons/gut/spy.gd`
```gdscript
var _calls = {}
var _lgr = GutUtils.get_logger()
var _compare = GutUtils.Comparator.new()
func _find_parameters(call_params, params_to_find):
	var found = false
	var idx = 0
		var result = _compare.deep(call_params[idx], params_to_find)
func _get_params_as_string(params):
	var to_return = ''
func add_call(variant, method_name, parameters=null):
func was_called(variant, method_name, parameters=null):
	var to_return = false
func get_call_parameters(variant, method_name, index=-1):
	var to_return = null
	var get_index = -1
		var call_size = _calls[variant][method_name].size()
func call_count(instance, method_name, parameters=null):
	var to_return = 0
func clear():
func get_call_list_as_string(instance):
	var to_return = ''
func get_logger():
func set_logger(logger):
```

### `res:///addons/gut/strutils.gd`
```gdscript
class_name GutStringUtils
var types = {}
func _init_types_dictionary():
var _str_ignore_types = [
func _init():
func _get_filename(path):
func _get_obj_filename(thing):
	var filename = null
		var dict = inst_to_dict(thing)
func type2str(thing):
	var filename = _get_obj_filename(thing)
	var str_thing = str(thing)
			var double_path = _get_filename(thing.__gutdbl.thepath)
			var double_type = "double"
func truncate_string(src, max_size):
	var to_return = src
func _get_indent_text(times, pad):
	var to_return = ''
func indent_text(text, times, pad):
	var to_return = text
	var ending_newline = ''
	var padding = _get_indent_text(times, pad)
```

### `res:///addons/gut/stub_params.gd`
```gdscript
var _is_return_override = false
var _is_defaults_override = false
var _is_call_override = false
var _method_meta : Dictionary = {}
var _lgr = GutUtils.get_logger()
var logger = _lgr :
var return_val = null
var stub_target = null
var parameters = null # the parameter values to match method call on.
var stub_method = null
var call_super = false
var call_this = null
var is_script_default = false
var parameter_count = -1 :
var parameter_defaults = []
const NOT_SET = '|_1_this_is_not_set_1_|'
func _init(target=null, method=null, _subpath=null):
func _load_defaults_from_metadata(meta):
	var values = meta.default_args.duplicate()
func _get_method_meta():
		var found_meta = GutUtils.get_method_meta(stub_target, stub_method)
func to_return(val):
func to_do_nothing():
func to_call_super():
func to_call(callable : Callable):
func when_passed(p1=NOT_SET,p2=NOT_SET,p3=NOT_SET,p4=NOT_SET,p5=NOT_SET,p6=NOT_SET,p7=NOT_SET,p8=NOT_SET,p9=NOT_SET,p10=NOT_SET):
	var idx = 0
func param_count(_x):
func param_defaults(values):
	var meta = _get_method_meta()
func is_default_override_only():
func is_return_override():
func is_defaults_override():
func is_call_override():
func to_s():
	var base_string = str(stub_target, '.', stub_method)
```

### `res:///addons/gut/stubber.gd`
```gdscript
static func _make_crazy_dynamic_over_engineered_class_db_hash():
	var text = "var all_the_classes: Dictionary = {\n"
	var inst =  GutUtils.create_script_from_source(text).new()
var returns = {}
var _lgr = GutUtils.get_logger()
var _strutils = GutUtils.Strutils.new()
func _find_matches(obj, method):
	var matches = []
	var last_not_null_parent = null
		var parent = obj.get_script()
		var found = false
			var base_type = last_not_null_parent.get_instance_base_type()
func _find_stub(obj, method, parameters=null, find_overloads=false):
	var to_return = null
	var matches = _find_matches(obj, method)
	var param_match = null
	var null_match = null
	var overload_match = null
		var cur_stub = matches[i]
func add_stub(stub_params):
	var key = stub_params.stub_target
func get_return(obj, method, parameters=null):
	var stub_info = _find_stub(obj, method, parameters)
func should_call_super(obj, method, parameters=null):
	var stub_info = _find_stub(obj, method, parameters)
	var is_partial = false
	var should = is_partial
func get_call_this(obj, method, parameters=null):
	var stub_info = _find_stub(obj, method, parameters)
func get_default_value(obj, method, p_index):
	var matches = _find_matches(obj, method)
	var the_defaults = []
	var script_defaults = []
	var i = matches.size() -1
	var to_return = null
func clear():
func get_logger():
func set_logger(logger):
func to_s():
	var text = ''
func stub_defaults_from_meta(target, method_meta):
	var params = GutUtils.StubParams.new(target, method_meta)
```

### `res:///addons/gut/summary.gd`
```gdscript
var _gut = null
func _init(gut=null):
func _log_end_run_header(gut):
	var lgr = gut.get_logger()
func _log_what_was_run(gut):
func _total_fmt(text, value):
	var space = 18
func _log_non_zero_total(text, value, lgr):
func _log_totals(gut, totals):
	var lgr = gut.get_logger()
	var issue_count = 0
func _log_nothing_run(gut):
	var lgr = gut.get_logger()
func log_all_non_passing_tests(gut=_gut):
	var test_collector = gut.get_test_collector()
	var lgr = gut.get_logger()
	var to_return = {
			var skip_msg = str('[Risky] Script was skipped:  ', test_script.skip_reason)
		var test_fail_count = 0
func log_the_final_line(totals, gut):
	var lgr = gut.get_logger()
	var grand_total_text = ""
	var grand_total_fmt = lgr.fmts.none
func log_totals(gut, totals):
	var lgr = gut.get_logger()
	var orig_indent = lgr.get_indent_level()
func get_totals(gut=_gut):
	var tc = gut.get_test_collector()
	var lgr = gut.get_logger()
	var totals = {
func log_end_run(gut=_gut):
	var totals = get_totals(gut)
	var lgr = gut.get_logger()
```

### `res:///addons/gut/test.gd`
```gdscript
class_name GutTest
extends Node
	var object = null
	var signal_name = null
	var sig = null
	var others := []
	func _init(p1, p2, p3=null, p4=null, p5=null, p6=null):
			signal_name = p1.get_name()
			signal_name = p2
const EDITOR_PROPERTY = PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_DEFAULT
const VARIABLE_PROPERTY = PROPERTY_USAGE_SCRIPT_VARIABLE
var DOUBLE_STRATEGY = GutUtils.DOUBLE_STRATEGY
var ParameterFactory = GutUtils.ParameterFactory
var CompareResult = GutUtils.CompareResult
var InputFactory = GutInputFactory
var InputSender = GutUtils.InputSender
var gut: GutMain = null
var collected_script = null
var wait_log_delay = .5 :
var _compare = GutUtils.Comparator.new()
var _disable_strict_datatype_checks = false
var _fail_pass_text = []
var _summary = {
var _signal_watcher = load('res://addons/gut/signal_watcher.gd').new()
var _lgr = GutUtils.get_logger()
var _strutils = GutUtils.Strutils.new()
var _awaiter = null
var _was_ready_called = false
func _do_ready_stuff():
func _ready():
func _notification(what):
func _str(thing):
func _str_precision(value, precision):
	var to_return = _str(value)
	var format = str('%.', precision, 'f')
func _fail(text):
func _pass(text):
func _do_datatypes_match__fail_if_not(got, expected, text):
	var did_pass = true
		var got_type = typeof(got)
		var expect_type = typeof(expected)
func _get_desc_of_calls_to_instance(inst):
	var BULLET = '  * '
	var calls = gut.get_spy().get_call_list_as_string(inst)
func _fail_if_does_not_have_signal(object, signal_name):
	var did_fail = false
func _fail_if_not_watching(object):
	var did_fail = false
func _get_fail_msg_including_emitted_signals(text, object):
func _fail_if_parameters_not_array(parameters):
	var invalid = parameters != null and typeof(parameters) != TYPE_ARRAY
func _get_bad_method_message(inst, method_name, what_you_cant_do):
	var to_return = ''
func _fail_if_not_double_or_does_not_have_method(inst, method_name):
	var to_return = OK
		var msg = _get_bad_method_message(inst, method_name, 'spy on')
func _create_obj_from_type(type):
	var obj = null
func _convert_spy_args(inst, method_name, parameters):
	var to_return = {
func _get_typeof_string(the_type):
	var to_return = ""
func _validate_singleton_name(singleton_name):
	var is_valid = true
		var txt = str("The singleton [", singleton_name, "] could not be found.  ",
func _warn_for_public_accessors(obj, property_name):
	var public_accessors = []
	var accessor_names = [
func _smart_double(thing, double_strat, partial):
	var override_strat = GutUtils.nvl(double_strat, gut.get_doubler().get_strategy())
	var to_return = null
func _are_double_parameters_valid(thing, p2, p3):
	var bad_msg = ""
func should_skip_script():
func before_all():
func before_each():
func after_each():
func after_all():
func pending(text=""):
func is_passing():
func is_failing():
func pass_test(text):
func fail_test(text):
func clear_signal_watcher():
func get_double_strategy():
func set_double_strategy(double_strategy):
func pause_before_teardown():
func get_logger():
func set_logger(logger):
func watch_signals(object):
func get_signal_emit_count(p1, p2=null):
	var sp = SignalAssertParameters.new(p1, p2)
func get_signal_parameters(p1, p2=null, p3=-1):
	var sp := SignalAssertParameters.new(p1, GutUtils.nvl(p2, -1), p3)
func get_call_parameters(object, method_name_or_index = -1, idx=-1):
	var to_return = null
	var index = idx
	var converted = _convert_spy_args(object, method_name_or_index, null)
func get_call_count(object, method_name=null, parameters=null):
	var converted = _convert_spy_args(object, method_name, parameters)
func simulate(obj, times, delta, check_is_processing: bool = false):
func replace_node(base_node, path_or_node, with_this):
	var path = path_or_node
	var to_replace = base_node.get_node(path)
	var parent = to_replace.get_parent()
	var replace_name = to_replace.get_name()
	var groups = to_replace.get_groups()
func use_parameters(params):
	var ph = gut.parameter_handler
	var output = str('- params[', ph.get_call_count(), ']','(', ph.get_current_parameters(), ')')
func run_x_times(x):
	var ph = gut.parameter_handler
		var params = []
func skip_if_godot_version_lt(expected):
	var should_skip = !GutUtils.is_godot_version_gte(expected)
func skip_if_godot_version_ne(expected):
	var should_skip = !GutUtils.is_godot_version(expected)
func register_inner_classes(base_script):
func compare_deep(v1, v2, max_differences=null):
	var result = _compare.deep(v1, v2)
func assert_eq(got, expected, text=""):
		var disp = "[" + _str(got) + "] expected to equal [" + _str(expected) + "]:  " + text
		var result = null
func assert_ne(got, not_expected, text=""):
		var disp = "[" + _str(got) + "] expected to not equal [" + _str(not_expected) + "]:  " + text
		var result = null
func assert_almost_eq(got, expected, error_interval, text=''):
	var disp = "[" + _str_precision(got, 20) + "] expected to equal [" + _str(expected) + "] +/- [" + str(error_interval) + "]:  " + text
func assert_almost_ne(got, not_expected, error_interval, text=''):
	var disp = "[" + _str_precision(got, 20) + "] expected to not equal [" + _str(not_expected) + "] +/- [" + str(error_interval) + "]:  " + text
func _is_almost_eq(got, expected, error_interval) -> bool:
	var result = false
	var upper = expected + error_interval
	var lower = expected - error_interval
func assert_gt(got, expected, text=""):
	var disp = "[" + _str(got) + "] expected to be > than [" + _str(expected) + "]:  " + text
func assert_gte(got, expected, text=""):
	var disp = "[" + _str(got) + "] expected to be >= than [" + _str(expected) + "]:  " + text
func assert_lt(got, expected, text=""):
	var disp = "[" + _str(got) + "] expected to be < than [" + _str(expected) + "]:  " + text
func assert_lte(got, expected, text=""):
	var disp = "[" + _str(got) + "] expected to be <= than [" + _str(expected) + "]:  " + text
func assert_true(got, text=""):
		var msg = str("Cannot convert ", _strutils.type2str(got), " to boolean")
func assert_false(got, text=""):
		var msg = str("Cannot convert ", _strutils.type2str(got), " to boolean")
func assert_between(got, expect_low, expect_high, text=""):
	var disp = "[" + _str_precision(got, 20) + "] expected to be between [" + _str(expect_low) + "] and [" + str(expect_high) + "]:  " + text
func assert_not_between(got, expect_low, expect_high, text=""):
	var disp = "[" + _str_precision(got, 20) + "] expected not to be between [" + _str(expect_low) + "] and [" + str(expect_high) + "]:  " + text
func assert_has(obj, element, text=""):
	var disp = str('Expected [', _str(obj), '] to contain value:  [', _str(element), ']:  ', text)
func assert_does_not_have(obj, element, text=""):
	var disp = str('Expected [', _str(obj), '] to NOT contain value:  [', _str(element), ']:  ', text)
func assert_file_exists(file_path):
	var disp = 'expected [' + file_path + '] to exist.'
func assert_file_does_not_exist(file_path):
	var disp = 'expected [' + file_path + '] to NOT exist'
func assert_file_empty(file_path):
	var disp = 'expected [' + file_path + '] to be empty'
func assert_file_not_empty(file_path):
	var disp = 'expected [' + file_path + '] to contain data'
func assert_has_method(obj, method, text=''):
	var disp = _str(obj) + ' should have method: ' + method
func assert_accessors(obj, property, default, set_to):
	var fail_count = _summary.failed
	var get_func = 'get_' + property
	var set_func = 'set_' + property
		get_func = 'is_' + property
func _find_object_property(obj, property_name, property_usage=null):
	var result = null
	var found = false
	var properties = obj.get_property_list()
		var property = properties.pop_back()
func assert_exports(obj, property_name, type):
	var disp = 'expected %s to have editor property [%s]' % [_str(obj), property_name]
	var property = _find_object_property(obj, property_name, EDITOR_PROPERTY)
func _can_make_signal_assertions(object, signal_name):
func _is_connected(signaler_obj, connect_to_obj, signal_name, method_name=""):
		var connections = signaler_obj.get_signal_connection_list(signal_name)
func assert_connected(p1, p2, p3=null, p4=""):
	var sp := SignalAssertParameters.new(p1, p3)
	var connect_to_obj = p2
	var method_name = p4
	var method_disp = ''
	var disp = str('Expected object ', _str(sp.object),\
func assert_not_connected(p1, p2, p3=null, p4=""):
	var sp := SignalAssertParameters.new(p1, p3)
	var connect_to_obj = p2
	var method_name = p4
	var method_disp = ''
	var disp = str('Expected object ', _str(sp.object),\
func assert_signal_emitted(p1, p2='', p3=""):
	var sp := SignalAssertParameters.new(p1, p2, p3)
	var disp = str('Expected object ', _str(sp.object), ' to have emitted signal [', sp.signal_name, ']:  ', sp.others[0])
func assert_signal_not_emitted(p1, p2='', p3=''):
	var sp := SignalAssertParameters.new(p1, p2, p3)
	var disp = str('Expected object ', _str(sp.object), ' to NOT emit signal [', sp.signal_name, ']:  ', sp.others[0])
func assert_signal_emitted_with_parameters(p1, p2, p3=-1, p4=-1):
	var sp := SignalAssertParameters.new(p1, p2, p3, p4)
	var parameters = sp.others[0]
	var index = sp.others[1]
	var disp = str('Expected object ', _str(sp.object), ' to emit signal [', sp.signal_name, '] with parameters ', parameters, ', got ')
			var parms_got = _signal_watcher.get_signal_parameters(sp.object, sp.signal_name, index)
			var diff_result = _compare.deep(parameters, parms_got)
			var text = str('Object ', sp.object, ' did not emit signal [', sp.signal_name, ']')
func assert_signal_emit_count(p1, p2, p3=0, p4=""):
	var sp := SignalAssertParameters.new(p1, p2, p3, p4)
	var times = sp.others[0]
	var text = sp.others[1]
		var count = _signal_watcher.get_emit_count(sp.object, sp.signal_name)
		var disp = str('Expected the signal [', sp.signal_name, '] emit count of [', count, '] to equal [', times, ']: ', text)
func assert_has_signal(object, signal_name, text=""):
	var disp = str('Expected object ', _str(object), ' to have signal [', signal_name, ']:  ', text)
func assert_is(object, a_class, text=''):
	var disp  = ''#var disp = str('Expected [', _str(object), '] to be type of [', a_class, ']: ', text)
	var bad_param_2 = 'Parameter 2 must be a Class (like Node2D or Label).  You passed '
		var a_str = _str(a_class)
func assert_typeof(object, type, text=''):
	var disp = str('Expected [typeof(', object, ') = ')
func assert_not_typeof(object, type, text=''):
	var disp = str('Expected [typeof(', object, ') = ')
func assert_string_contains(text, search, match_case=true):
	const empty_search = 'Expected text and search strings to be non-empty. You passed %s and %s.'
	const non_strings = 'Expected text and search to both be strings.  You passed %s and %s.'
	var disp = 'Expected \'%s\' to contain \'%s\', match_case=%s' % [text, search, match_case]
func assert_string_starts_with(text, search, match_case=true):
	var empty_search = 'Expected text and search strings to be non-empty. You passed \'%s\' and \'%s\'.'
	var disp = 'Expected \'%s\' to start with \'%s\', match_case=%s' % [text, search, match_case]
func assert_string_ends_with(text, search, match_case=true):
	var empty_search = 'Expected text and search strings to be non-empty. You passed \'%s\' and \'%s\'.'
	var disp = 'Expected \'%s\' to end with \'%s\', match_case=%s' % [text, search, match_case]
	var required_index = len(text) - len(search)
func assert_called(inst, method_name=null, parameters=null):
	var converted = _convert_spy_args(inst, method_name, parameters)
	var disp = str('Expected [',converted.method_name,'] to have been called on ',_str(converted.object))
func assert_not_called(inst, method_name=null, parameters=null):
	var converted = _convert_spy_args(inst, method_name, parameters)
	var disp = str('Expected [', converted.method_name, '] to NOT have been called on ', _str(converted.object))
func assert_called_count(callable : Callable, expected_count : int):
	var converted = _convert_spy_args(callable, null, null)
	var count = gut.get_spy().call_count(converted.object, converted.method_name, converted.arguments)
	var param_text = ''
	var disp = 'Expected [%s] on %s to be called [%s] times%s.  It was called [%s] times.'
func assert_null(got, text=''):
	var disp = str('Expected [', _str(got), '] to be NULL:  ', text)
func assert_not_null(got, text=''):
	var disp = str('Expected [', _str(got), '] to be anything but NULL:  ', text)
func assert_freed(obj, title='something'):
	var disp = title
func assert_not_freed(obj, title='something'):
	var disp = title
func assert_no_new_orphans(text=''):
	var orphan_ids = gut.get_current_test_orphans()
	var count = orphan_ids.size()
	var msg = ''
func assert_set_property(obj, property_name, new_value, expected_value):
func assert_readonly_property(obj, property_name, new_value, expected_value):
func assert_property_with_backing_variable(obj, property_name, default_value, new_value, backed_by_name=null):
	var setter_name = str('@', property_name, '_setter')
	var getter_name = str('@', property_name, '_getter')
	var backing_name = GutUtils.nvl(backed_by_name, str('_', property_name))
	var pre_fail_count = get_fail_count()
	var props = obj.get_property_list()
	var found = false
	var idx = 0
		var call_setter = Callable(obj, setter_name)
		var call_getter = Callable(obj, getter_name)
func assert_property(obj, property_name, default_value, new_value) -> void:
	var pre_fail_count = get_fail_count()
	var setter_name = str('@', property_name, '_setter')
	var getter_name = str('@', property_name, '_getter')
		var call_setter = Callable(obj, setter_name)
		var call_getter = Callable(obj, getter_name)
func assert_eq_deep(v1, v2):
	var result = compare_deep(v1, v2)
func assert_ne_deep(v1, v2):
	var result = compare_deep(v1, v2)
func assert_same(v1, v2, text=''):
	var disp = "[" + _str(v1) + "] expected to be same as  [" + _str(v2) + "]:  " + text
func assert_not_same(v1, v2, text=''):
	var disp = "[" + _str(v1) + "] expected to not be same as  [" + _str(v2) + "]:  " + text
var _error_type_check_methods = {
func _is_error_of_type(err, error_type_name):
func _assert_error_count(count, error_type_name, msg):
	var consumed_count = 0
	var errors = gut.error_tracker.get_errors_for_test()
	var found = []
	var disp = msg
func _assert_error_text(text, error_type_name, msg):
	var consumed_count = 0
	var errors = gut.error_tracker.get_errors_for_test()
	var found = []
	var disp = msg
func get_errors()->Array:
func assert_engine_error(count_or_text, msg=''):
	var t = typeof(count_or_text)
func assert_push_error(count_or_text, msg=''):
	var t = typeof(count_or_text)
func wait_seconds(time, msg=''):
func wait_for_signal(sig : Signal, max_time, msg=''):
func wait_frames(frames : int, msg=''):
func wait_physics_frames(x :int , msg=''):
		var text = str('wait_physics_frames:  frames must be > 0, you passed  ', x, '.  1 frames waited.')
func wait_idle_frames(x : int, msg=''):
func wait_process_frames(x : int, msg=''):
		var text = str('wait_process_frames:  frames must be > 0, you passed  ', x, '.  1 frames waited.')
func wait_until(callable, max_time, p3='', p4=''):
	var time_between = 0.0
	var message = p4
func wait_while(callable, max_time, p3='', p4=''):
	var time_between = 0.0
	var message = p4
func did_wait_timeout():
func get_summary():
func get_fail_count():
func get_pass_count():
func get_pending_count():
func get_assert_count():
func get_summary_text():
	var to_return = get_script().get_path() + "\n"
func double(thing, double_strat=null, not_used_anymore=null):
func partial_double(thing, double_strat=null, not_used_anymore=null):
func double_singleton(singleton_name):
func partial_double_singleton(singleton_name):
func ignore_method_when_doubling(thing, method_name):
	var r = thing
func stub(thing, p2=null, p3=null):
	var method_name = p2
	var subpath = null
	var sp = null
		var msg = _get_bad_method_message(sp.stub_target, sp.stub_method, 'stub')
func autofree(thing):
func autoqfree(thing):
func add_child_autofree(node, legible_unique_name = false):
func add_child_autoqfree(node, legible_unique_name=false):
func compare_shallow(v1, v2, max_differences=null):
func assert_eq_shallow(v1, v2):
func assert_ne_shallow(v1, v2):
func yield_for(time, msg=''):
func yield_to(obj, signal_name, max_wait, msg=''):
func yield_frames(frames, msg=''):
func double_scene(path, strategy=null):
func double_script(path, strategy=null):
func double_inner(path, subpath, strategy=null):
	var override_strat = GutUtils.nvl(strategy, gut.get_doubler().get_strategy())
func assert_call_count(inst, method_name, expected_count, parameters=null):
	var callable = Callable.create(inst, method_name)
func assert_setget(
	const_or_setter = null, getter="__not_set__"):
```

### `res:///addons/gut/test_collector.gd`
```gdscript
var CollectedScript = GutUtils.CollectedScript
var CollectedTest = GutUtils.CollectedTest
var _test_prefix = 'test_'
var _test_class_prefix = 'Test'
var _lgr = GutUtils.get_logger()
var scripts = []
func _does_inherit_from_test(thing):
	var base_script = thing.get_base_script()
	var to_return = false
		var base_path = base_script.get_path()
func _populate_tests(test_script):
	var script =  test_script.load_script()
	var methods = script.get_script_method_list()
		var name = methods[i]['name']
			var t = CollectedTest.new()
func _get_inner_test_class_names(loaded):
	var inner_classes = []
	var const_map = loaded.get_script_constant_map()
		var thing = const_map[key]
func _parse_script(test_script):
	var inner_classes = []
	var scripts_found = []
	var loaded = GutUtils.WarningsManager.load_script_using_custom_warnings(
		var loaded_inner = loaded.get(inner_classes[i])
			var ts = CollectedScript.new(_lgr)
func add_script(path):
	var ts = CollectedScript.new(_lgr)
	var parse_results = _parse_script(ts)
func clear():
func has_script(path):
	var found = false
	var idx = 0
func export_tests(path):
	var success = true
	var f = ConfigFile.new()
	var result = f.save(path)
func import_tests(path):
	var success = false
	var f = ConfigFile.new()
	var result = f.load(path)
		var sections = f.get_sections()
			var ts = CollectedScript.new(_lgr)
func get_script_named(name):
func get_test_named(script_name, test_name):
	var s = get_script_named(script_name)
func to_s():
	var to_return = ''
func get_logger():
func set_logger(logger):
func get_test_prefix():
func set_test_prefix(test_prefix):
func get_test_class_prefix():
func set_test_class_prefix(test_class_prefix):
func get_scripts():
func get_ran_test_count():
	var count = 0
func get_ran_script_count():
	var count = 0
func get_test_count():
	var count = 0
func get_assert_count():
	var count = 0
func get_pass_count():
	var count = 0
func get_fail_count():
	var count = 0
func get_pending_count():
	var count = 0
```

### `res:///addons/gut/thing_counter.gd`
```gdscript
var things = {}
func get_unique_count():
func add_thing_to_count(thing):
func add(thing):
func has(thing):
func count(thing):
	var to_return = 0
func sum():
	var to_return = 0
func to_s():
	var to_return = ""
func get_max_count():
	var max_val = null
func add_array_items(array):
```

### `res:///addons/gut/utils.gd`
```gdscript
class_name GutUtils
extends Object
const GUT_METADATA = '__gutdbl'
enum DOUBLE_STRATEGY{
enum DIFF {
const TEST_STATUSES = {
const DOUBLE_TEMPLATES = {
const NOTHING := '__NOTHING__'
const NO_TEST := 'NONE'
const GUT_ERROR_TYPE = 999
enum TREAT_AS {
static func get_logger():
static func get_error_tracker():
static func create_script_from_source(source, override_path=null):
	var are_warnings_enabled = WarningsManager.are_warnings_enabled()
	var DynamicScript = _dyn_gdscript.create_script_from_source(source, override_path)
		var l = get_logger()
static func get_editor_interface():
		var inst = load("res://addons/gut/get_editor_interface.gd").new()
static func godot_version_string():
static func is_godot_version(expected):
static func is_godot_version_gte(expected):
const INSTALL_OK_TEXT = 'Everything checks out'
static func make_install_check_text(template_paths=DOUBLE_TEMPLATES, ver_nums=version_numbers):
	var text = INSTALL_OK_TEXT
static func is_install_valid(template_paths=DOUBLE_TEMPLATES, ver_nums=version_numbers):
static func get_enum_value(thing, e, default=null):
	var to_return = default
		var converted = thing.to_upper().replace(' ', '_')
static func nvl(value, if_null):
static func pretty_print(dict, indent = '  '):
static func print_properties(props, thing, print_all_meta=false):
		var prop_name = props[i].name
		var prop_value = thing.get(props[i].name)
		var print_value = str(prop_value)
static func print_method_list(thing):
static func get_scene_script_object(scene):
	var state = scene.get_state()
	var to_return = null
	var root_node_path = NodePath(".")
	var node_idx = 0
static func is_freed(obj):
	var wr = weakref(obj)
static func is_not_freed(obj):
static func is_double(obj):
	var to_return = false
static func is_native_class(thing):
	var it_is = false
static func is_instance(obj):
static func is_gdscript(obj):
static func is_inner_class(obj):
static func extract_property_from_array(source, property):
	var to_return = []
static func is_null_or_empty(text):
static func get_native_class_name(thing):
	var to_return = null
			var newone = thing.new()
static func write_file(path, content):
	var f = FileAccess.open(path, FileAccess.WRITE)
static func get_file_as_text(path):
	var to_return = ''
	var f = FileAccess.open(path, FileAccess.READ)
		var err = FileAccess.get_open_error()
static func search_array_idx(ar, prop_method, value):
	var found = false
	var idx = 0
		var item = ar[idx]
		var prop = item.get(prop_method)
			var called_val = prop.call()
static func search_array(ar, prop_method, value):
	var idx = search_array_idx(ar, prop_method, value)
static func are_datatypes_same(got, expected):
static func get_script_text(obj):
static func dec2bistr(decimal_value, max_bits = 31):
	var binary_string = ""
	var temp
	var count = max_bits
static func add_line_numbers(contents):
	var to_return = ""
	var lines = contents.split("\n")
	var line_num = 1
		var line_str = str(line_num).lpad(6, ' ')
static func get_display_size():
static func find_method_meta(methods, method_name):
	var meta = null
	var idx = 0
		var m = methods[idx]
static func get_method_meta(object, method_name):
```

### `res:///addons/gut/version_conversion.gd`
```gdscript
	var EditorGlobals = load("res://addons/gut/gui/editor_globals.gd")
	func warn(message):
	func info(message):
	func moved_file(from, to):
			var result = DirAccess.copy_absolute(from, to)
	func move_user_file(from, to):
				var result = DirAccess.copy_absolute(from, to)
	func remove_user_file(which):
			var result = DirAccess.remove_absolute(which)
	extends ConfigurationUpdater
	func validate():
static func get_missing_gut_class_names() -> Array:
	var gut_class_names = [
	var class_cach_path = 'res://.godot/global_script_class_cache.cfg'
	var cfg = ConfigFile.new()
	var all_class_names = {}
	var missing  = []
	var class_cache_entries = cfg.get_value('', 'list', [])
static func error_if_not_all_classes_imported() -> bool:
	var missing_class_names = get_missing_gut_class_names()
static func convert():
	var inst = v9_2_0.new()
```

### `res:///addons/gut/version_numbers.gd`
```gdscript
	static func _make_version_array_from_string(v):
		var parts = Array(v.split('.'))
			var int_val = parts[i].to_int()
	static func make_version_array(v):
		var to_return = []
	static func make_version_string(version_parts):
		var to_return = 'x.x.x'
	static func is_version_gte(version, required):
		var is_ok = null
		var v = make_version_array(version)
		var r = make_version_array(required)
		var idx = 0
	static func is_version_eq(version, expected):
		var version_array = make_version_array(version)
		var expected_array = make_version_array(expected)
		var is_version = true
		var i = 0
	static func is_godot_version_eq(expected):
	static func is_godot_version_gte(expected):
var gut_version = '0.0.0'
var required_godot_version = '0.0.0'
func _init(gut_v = gut_version, required_godot_v = required_godot_version):
func get_version_text():
	var v_info = Engine.get_version_info()
	var gut_version_info =  str('GUT version:  ', gut_version)
	var godot_version_info  = str('Godot version:  ', v_info.major,  '.',  v_info.minor,  '.',  v_info.patch)
func get_bad_version_text():
	var info = Engine.get_version_info()
	var gd_version = str(info.major, '.', info.minor, '.', info.patch)
func is_godot_version_valid():
func make_godot_version_string():
```

### `res:///addons/gut/warnings_manager.gd`
```gdscript
const IGNORE = 0
const WARN = 1
const ERROR = 2
const WARNING_LOOKUP = {
const GDSCRIPT_WARNING = 'debug/gdscript/warnings/'
static func _static_init():
static func are_warnings_enabled():
static func enable_warnings(should=true):
static func exclude_addons(should=true):
static func reset_warnings():
static func set_project_setting_warning(warning_name : String, value : Variant):
	var property_name = str(GDSCRIPT_WARNING, warning_name)
static func apply_warnings_dictionary(warning_values : Dictionary):
static func create_ignore_all_dictionary():
static func create_warn_all_warnings_dictionary():
static func replace_warnings_with_ignore(dict):
static func replace_errors_with_warnings(dict):
static func replace_warnings_values(dict, replace_this, with_this):
	var to_return = dict.duplicate()
static func create_warnings_dictionary_from_project_settings() -> Dictionary :
	var props = ProjectSettings.get_property_list()
	var to_return = {}
			var prop_name = props[i].name.replace(GDSCRIPT_WARNING, '')
static func print_warnings_dictionary(which : Dictionary):
	var is_valid = true
		var value_str = str(which[key])
		var s = str(key, ' = ', value_str)
static func load_script_ignoring_all_warnings(path : String) -> Variant:
static func load_script_using_custom_warnings(path : String, warnings_dictionary : Dictionary) -> Variant:
	var current_warns = create_warnings_dictionary_from_project_settings()
	var s = load(path)
```

### `res:///addons/loggie/channels/discord.gd`
```gdscript
class_name DiscordLoggieMsgChannel extends LoggieMsgChannel
const discord_msg_character_limit = 2000 # The max. amount of characters the content of the message can contain before discord refuses to post it.
var debug_domain = "_d_loggie_discord"
var debug_enabled = false
func _init() -> void:
func send(msg : LoggieMsg, msg_type : LoggieEnums.MsgType):
	var loggie = msg.get_logger()
	var webhook_url = loggie.settings.discord_webhook_url_live if loggie.is_in_production() else loggie.settings.discord_webhook_url_dev
	var output_text = LoggieTools.convert_string_to_format_mode(msg.last_preprocess_result, LoggieEnums.MsgFormatMode.MARKDOWN)
	var chunks = LoggieTools.chunk_string(output_text, discord_msg_character_limit)
func send_post_request(logger : Variant, output_text : String, webhook_url : String):
	var http = HTTPRequest.new()
		var debug_msg = logger.msg("HTTP Request Completed:").color(Color.ORANGE).header().domain(debug_domain).channel("terminal")
	var json = JSON.stringify({"content": output_text})
	var header = ["Content-Type: application/json"]
		var debug_msg_post = logger.msg("Sending POST Request:").color(Color.CORNFLOWER_BLUE).header().channel("terminal").domain(debug_domain).nl()
```

### `res:///addons/loggie/channels/slack.gd`
```gdscript
class_name SlackLoggieMsgChannel extends LoggieMsgChannel
var debug_domain = "_d_loggie_slack"
var debug_enabled = false
func _init() -> void:
func send(msg : LoggieMsg, msg_type : LoggieEnums.MsgType):
	var loggie = msg.get_logger()
	var webhook = loggie.settings.slack_webhook_url_live if loggie.is_in_production() else loggie.settings.slack_webhook_url_dev
	var http = HTTPRequest.new()
		var debug_msg = loggie.msg("HTTP Request Completed:").color(Color.ORANGE).header().domain(debug_domain)
	var md_text = LoggieTools.convert_string_to_format_mode(msg.last_preprocess_result, LoggieEnums.MsgFormatMode.PLAIN)
	var json = JSON.stringify({"text": md_text})
	var header = ["Content-Type: application/json"]
		var debug_msg_post = loggie.msg("Sending POST Request:").color(Color.ORANGE).header().domain(debug_domain).nl()
```

### `res:///addons/loggie/channels/terminal.gd`
```gdscript
class_name TerminalLoggieMsgChannel extends LoggieMsgChannel
func _init() -> void:
func send(msg : LoggieMsg, msg_type : LoggieEnums.MsgType):
	var loggie = msg.get_logger()
	var text = LoggieTools.convert_string_to_format_mode(msg.last_preprocess_result, loggie.settings.msg_format_mode)
```

### `res:///addons/loggie/loggie.gd`
```gdscript
extends Node
var version : LoggieVersion = LoggieVersion.new(3,0)
signal log_attempted(msg : LoggieMsg, msg_string : String, result : LoggieEnums.LogAttemptResult)
var settings : LoggieSettings
var domains : Dictionary = {}
var class_names : Dictionary = {}
var available_channels = {}
var version_manager : LoggieVersionManager = LoggieVersionManager.new()
var presets : Dictionary = {}
func _init() -> void:
	var uses_original_settings_file = true
	var default_settings_path = get_script().get_path().get_base_dir().path_join("loggie_settings.gd")
	var custom_settings_path = get_script().get_path().get_base_dir().path_join("custom_settings.gd")
			var loaded_successfully = load_settings_from_path(custom_settings_path)
		var _settings = ResourceLoader.load(default_settings_path)
	var terminal_channel : TerminalLoggieMsgChannel = load("res://addons/loggie/channels/terminal.gd").new()
	var discord_channel : DiscordLoggieMsgChannel = load("res://addons/loggie/channels/discord.gd").new()
	var slack_channel : SlackLoggieMsgChannel = load("res://addons/loggie/channels/slack.gd").new()
	class_names[self.get_script().resource_path] = LoggieSettings.loggie_singleton_name
			class_names[class_data.path] = class_data.class
			var autoload_class: String = autoload_setting.trim_prefix("autoload/")
			var class_path: String = ProjectSettings.get_setting(autoload_setting)
				class_names[class_path] = autoload_class
		var loggie_specs_msg = LoggieSystemSpecsMsg.new().use_logger(self)
		var system_specs_msg = LoggieSystemSpecsMsg.new().use_logger(self)
func load_settings_from_path(path : String) -> bool:
	var settings_resource = ResourceLoader.load(path)
	var settings_instance
func is_in_production() -> bool:
func get_domain_custom_target_channels(domain_name : String) -> Array:
func set_domain_enabled(domain_name : String, enabled : bool, custom_target_channels : Variant = []) -> void:
	var pruned_target_channels = []
func is_domain_enabled(domain_name : String) -> bool:
func get_channel(channel_id : String) -> LoggieMsgChannel:
func add_channel(channel : LoggieMsgChannel):
func preset(id : String) -> LoggiePreset:
		var newPreset : LoggiePreset = LoggiePreset.new()
func msg(message = "", arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null) -> LoggieMsg:
	var loggieMsg = LoggieMsg.new(message, arg1, arg2, arg3, arg4, arg5)
func info(message = "", arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null) -> LoggieMsg:
func warn(message = "", arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null) -> LoggieMsg:
func error(message = "", arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null) -> LoggieMsg:
func debug(message = "", arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null) -> LoggieMsg:
func notice(message = "", arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null) -> LoggieMsg:
func get_directory_path() -> String:
func stack() -> LoggieMsg:
	const FALLBACK_TXT_TO_FORMAT = "{index}: {fn_name}:{line} (in {source_path})"
	var stack = get_stack()
	var stack_msg = msg()
	var text_to_format = settings.format_stacktrace_entry if is_instance_valid(settings) else FALLBACK_TXT_TO_FORMAT
		var file_name = stack[index].source.get_file().get_basename()
		var entry_msg = LoggieMsg.new()
func apply_production_optimal_settings():
```

### `res:///addons/loggie/loggie_message.gd`
```gdscript
class_name LoggieMsg extends RefCounted
var content : Array = [""]
var current_segment_index : int = 0
var domain_name : String = ""
var _logger : Variant
var used_channels : Array = ["terminal"]
var preprocess : bool = true
var custom_preprocess_flags : int = -1
var last_preprocess_result : String = ""
var last_outputted_at_log_level : int = -1
var appends_stack : bool = false
var dynamic_type : bool = true
var strict_type : LoggieEnums.MsgType = LoggieEnums.MsgType.INFO
var environment_mode : LoggieEnums.MsgEnvironment = LoggieEnums.MsgEnvironment.BOTH
var dont_emit_log_attempted_signal : bool = false
func _init(message = "", arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null) -> void:
	var args = [message, arg1, arg2, arg3, arg4, arg5]
func get_logger() -> Variant:
func use_logger(logger_to_use : Variant) -> LoggieMsg:
		var initial_args = self.get_meta("initial_args")
			var converter_fn = self._logger.settings.custom_string_converter if is_instance_valid(self._logger) and is_instance_valid(self._logger.settings) else null
func channel(channels : Variant) -> LoggieMsg:
func get_preprocessed(flags : int, _level : LoggieEnums.LogLevel, type : LoggieEnums.MsgType) -> String:
	var loggie = get_logger()
	var message = self.string()
func output(level : LoggieEnums.LogLevel, msg_type : LoggieEnums.MsgType = LoggieEnums.MsgType.INFO) -> void:
	var loggie = get_logger()
	var message = self.string()
	var target_domain = self.domain_name
	var target_channels = self.used_channels
	var custom_target_channels = loggie.get_domain_custom_target_channels(target_domain)
		var channel : LoggieMsgChannel = loggie.get_channel(channel_id)
			var flags = self.custom_preprocess_flags if self.custom_preprocess_flags != -1 else channel.preprocess_flags
func error() -> LoggieMsg:
func warn() -> LoggieMsg:
func notice() -> LoggieMsg:
func info() -> LoggieMsg:
func debug() -> LoggieMsg:
func string(segment : int = -1) -> String:
func to_ANSI() -> LoggieMsg:
	var new_content : Array = []
func strip_BBCode() -> LoggieMsg:
	var new_content : Array = []
func color(_color : Variant) -> LoggieMsg:
func bold() -> LoggieMsg:
func italic() -> LoggieMsg:
func link(url : String, _color : Variant = null) -> LoggieMsg:
func header() -> LoggieMsg:
	var loggie = get_logger()
func stack(enabled : bool = true) -> LoggieMsg:
func box(h_padding : int = 4) -> LoggieMsg:
	var loggie = get_logger()
	var stripped_content = LoggieTools.remove_BBCode(self.content[current_segment_index]).strip_edges(true, true)
	var content_length = stripped_content.length()
	var h_fill_length = content_length + (h_padding * 2)
	var box_character_source = loggie.settings.box_symbols_compatible if loggie.settings.box_characters_mode == LoggieEnums.BoxCharactersMode.COMPATIBLE else loggie.settings.box_symbols_pretty
	var top_row_design = "{top_left_corner}{h_fill}{top_right_corner}".format({
	var middle_row_design = "{vert_line}{padding}{content}{space_fill}{padding}{vert_line}".format({
	var bottom_row_design = "{bottom_left_corner}{h_fill}{bottom_right_corner}".format({
func add(message : Variant = null, arg1 : Variant = null, arg2 : Variant = null, arg3 : Variant = null, arg4 : Variant = null, arg5 : Variant = null) -> LoggieMsg:
	var converter_fn = self._logger.settings.custom_string_converter if is_instance_valid(self._logger) and is_instance_valid(self._logger.settings) else null
func nl(amount : int = 1) -> LoggieMsg:
func space(amount : int = 1) -> LoggieMsg:
func tab(amount : int = 1) -> LoggieMsg:
func domain(_domain_name : String) -> LoggieMsg:
func prefix(str_prefix : String, separator : String = "") -> LoggieMsg:
func suffix(str_suffix : String, separator : String = "") -> LoggieMsg:
func hseparator(size : int = 16, alternative_symbol : Variant = null) -> LoggieMsg:
	var loggie = get_logger()
	var symbol = loggie.settings.h_separator_symbol if alternative_symbol == null else str(alternative_symbol)
func endseg() -> LoggieMsg:
func env(mode : LoggieEnums.MsgEnvironment) -> LoggieMsg:
func msg(message = "", arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null) -> LoggieMsg:
	var converter_fn = self._logger.settings.custom_string_converter if is_instance_valid(self._logger) and is_instance_valid(self._logger.settings) else null
func preprocessed(shouldPreprocess : bool) -> LoggieMsg:
func type(loggie_enums_msgtype_key_or_value : Variant) -> LoggieMsg:
	var isValid = false
	var _type : LoggieEnums.MsgType
		var uppercase_key = loggie_enums_msgtype_key_or_value.to_upper()
func no_signal(enabled : bool = true) -> LoggieMsg:
func preset(id : String, apply_only_to_current_segment : bool = false) -> LoggieMsg:
	var loggie = get_logger()
	var preset_to_use : LoggiePreset = loggie.preset(id)
func _emit_log_attempted_signal(result : LoggieEnums.LogAttemptResult, call_deferred : bool = false) -> void:
	var loggie = get_logger()
	var string_content = self.string()
func _apply_format_domain(message : String) -> String:
	var loggie = get_logger()
func _apply_format_class_name(message : String) -> String:
	var loggie = get_logger()
	var stack_frame : Dictionary = LoggieTools.get_current_stack_frame_data()
	var _class_name : String
	var scriptPath = stack_frame.source
func _apply_format_timestamp(message : String) -> String:
	var loggie = get_logger()
	var format_dict : Dictionary = Time.get_datetime_dict_from_system(loggie.settings.timestamps_use_utc)
	var unix_time: float = Time.get_unix_time_from_system()
	var millisecond: int = int((unix_time - int(unix_time)) * 1000.0)
	var elapsed_millisecond: int = Time.get_ticks_msec()
	var startup_hour: int = elapsed_millisecond / 3_600_000
	var startup_minute: int = (elapsed_millisecond % 3_600_000) / 60_000
	var startup_second: int = (elapsed_millisecond % 60_000) / 1000
	var startup_millisecond: int = elapsed_millisecond % 1000
func _apply_format_stack(message : String) -> String:
	var loggie = get_logger()
	var stack_msg = loggie.stack()
```

### `res:///addons/loggie/loggie_message_channel.gd`
```gdscript
class_name LoggieMsgChannel extends RefCounted
var ID : String = ""
var preprocess_flags : int = 0
func send(msg : LoggieMsg, type : LoggieEnums.MsgType):
```

### `res:///addons/loggie/loggie_preset.gd`
```gdscript
class_name LoggiePreset extends LoggieMsg
const content_placeholder = "{content}"
func _init(message = "", arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null) -> void:
func apply_to(msg : LoggieMsg, only_to_current_segment : bool = false) -> LoggieMsg:
	var content_to_apply_preset_to : String
		var new_segment_content = self.content[0].format({"content": content_to_apply_preset_to})
		var new_message_content = self.content[0].format({"content": content_to_apply_preset_to})
func endseg() -> LoggieMsg:
func msg(message = "", arg1 = null, arg2 = null, arg3 = null, arg4 = null, arg5 = null) -> LoggieMsg:
func output(level : LoggieEnums.LogLevel, msg_type : LoggieEnums.MsgType = LoggieEnums.MsgType.INFO) -> void:
```

### `res:///addons/loggie/loggie_settings.gd`
```gdscript
class_name LoggieSettings extends Resource
const project_settings = {
var update_check_mode : LoggieEnums.UpdateCheckType = LoggieEnums.UpdateCheckType.CHECK_AND_SHOW_UPDATER_WINDOW
var msg_format_mode : LoggieEnums.MsgFormatMode = LoggieEnums.MsgFormatMode.BBCODE
var log_level : LoggieEnums.LogLevel = LoggieEnums.LogLevel.INFO
var show_loggie_specs : LoggieEnums.ShowLoggieSpecsMode = LoggieEnums.ShowLoggieSpecsMode.ESSENTIAL
var show_system_specs : bool = true
var print_errors_to_console : bool = true
var print_warnings_to_console : bool = true
var nameless_class_name_proxy : LoggieEnums.NamelessClassExtensionNameProxy
var timestamps_use_utc : bool = true
var debug_msgs_print_stack_trace : bool = false
var enforce_optimal_settings_in_release_build : bool = true
var discord_webhook_url_dev : String = "" 
var discord_webhook_url_live : String = "" 
var slack_webhook_url_dev : String = "" 
var slack_webhook_url_live : String = "" 
var preprocess_flags_terminal_channel = LoggieEnums.PreprocessStep.APPEND_TIMESTAMPS | LoggieEnums.PreprocessStep.APPEND_DOMAIN_NAME | LoggieEnums.PreprocessStep.APPEND_CLASS_NAME
var preprocess_flags_discord_channel = LoggieEnums.PreprocessStep.APPEND_DOMAIN_NAME | LoggieEnums.PreprocessStep.APPEND_CLASS_NAME
var preprocess_flags_slack_channel = LoggieEnums.PreprocessStep.APPEND_DOMAIN_NAME | LoggieEnums.PreprocessStep.APPEND_CLASS_NAME
var default_channels : PackedStringArray = ["terminal"]
var skipped_filenames_in_stack_trace : PackedStringArray = ["loggie", "loggie_message"]
var format_header = "[b][i]{msg}[/i][/b]"
var format_domain_prefix = "[b]({domain})[/b] {msg}"
var format_error_msg = "[b][color=red][ERROR]:[/color][/b] {msg}"
var format_warning_msg = "[b][color=orange][WARN]:[/color][/b] {msg}"
var format_notice_msg = "[b][color=cyan][NOTICE]:[/color][/b] {msg}"
var format_info_msg = "{msg}"
var format_debug_msg = "[b][color=pink][DEBUG]:[/color][/b] {msg}"
var format_timestamp = "[{day}.{month}.{year} {hour}:{minute}:{second}]"
var format_stacktrace_entry = "{index}: [color=#ff7085]func[/color] [color=#53b1c3][b]{fn_name}[/b]:{line}[/color] [color=slate_gray][i](in {source_path})[/i][/color]"
var h_separator_symbol = "-"
var box_characters_mode : LoggieEnums.BoxCharactersMode
var box_symbols_compatible = {
var box_symbols_pretty = {
var custom_string_converter : Callable
func load():
func to_dict() -> Dictionary:
	var dict = {}
	var included = [
```

### `res:///addons/loggie/plugin.gd`
```gdscript
class_name LoggieEditorPlugin extends EditorPlugin
func _enter_tree():
func _enable_plugin() -> void:
func _disable_plugin() -> void:
	var wipe_setting_exists = ProjectSettings.has_setting(LoggieSettings.project_settings.remove_settings_if_plugin_disabled.path)
func add_loggie_project_settings():
func remove_loggie_project_setings():
	var error: int = ProjectSettings.save()
func add_project_setting(setting_name: String, default_value : Variant, value_type: int, type_hint: int = PROPERTY_HINT_NONE, hint_string: String = "", documentation : String = ""):
	var error: int = ProjectSettings.save()
```

### `res:///addons/loggie/tools/UIAssetGenerator.gd`
```gdscript
extends EditorScript
const OUT_PATH = "res://ui/assets/"
const SIZE = 256
func _run() -> void:
func _gen_parchment() -> void:
	var img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var noise = FastNoiseLite.new()
			var col = Color("#aeb5bd")
			var n = noise.get_noise_2d(x, y)
func _gen_wood() -> void:
	var img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var noise = FastNoiseLite.new()
			var n = noise.get_noise_2d(x * 0.1, y * 4.0) 
			var base = Color("#4a3c31") 
func _gen_shield() -> void:
	var s = 128
	var img = Image.create(s, s, false, Image.FORMAT_RGBA8)
	var center = Vector2(s / 2.0, s / 2.0)
	var radius = (s / 2.0) - 2.0
			var d = Vector2(x, y).distance_to(center)
					var grain = sin(x * 0.5) * 0.1
					var base = Color("#6d543e").lightened(grain)
func _gen_wax_seal() -> void:
	var s = 64
	var img = Image.create(s, s, false, Image.FORMAT_RGBA8)
	var center = Vector2(s / 2.0, s / 2.0)
	var radius = (s / 2.0) - 4.0
			var d = Vector2(x, y).distance_to(center)
				var col = Color("#a83232") 
func _gen_scroll_vertical() -> void:
	var w = 256
	var h = 512
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
			var col = Color("#f5e6d3")
			var dist_x = min(x, w - x)
func _gen_tapestry() -> void:
	var img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
			var weave = (int(x) % 4 == 0) or (int(y) % 4 == 0)
			var col = Color("#2e222f") 
func _gen_resource_tag() -> void:
	var w = 128
	var h = 48
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
			var col = Color("#2F2F2F")
func _gen_tooltip_bg() -> void:
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		var gold = Color("#c5a54e")
func _gen_resource_icons() -> void:
	var resources = ["res_gold", "res_wood", "res_food", "res_stone", "res_peasant", "res_thrall"]
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		var fill_rect = func(rect: Rect2i, color: Color):
		var fill_circle = func(center: Vector2, radius: float, color: Color):
func _gen_icons() -> void:
	var icons = ["icon_build", "icon_army", "icon_crown", "icon_map", "icon_time", "icon_manage", "icon_family"]
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		var col = Color.WHITE 
		var draw_box = func(r: Rect2i):
```

### `res:///addons/loggie/tools/loggie_enums.gd`
```gdscript
class_name LoggieEnums extends Node
enum LogLevel {
enum MsgType {
enum MsgFormatMode {
enum PreprocessStep {
enum BoxCharactersMode {
enum NamelessClassExtensionNameProxy {
enum ShowLoggieSpecsMode {
enum LogAttemptResult {
enum UpdateCheckType {
enum MsgEnvironment {
```

### `res:///addons/loggie/tools/loggie_system_specs.gd`
```gdscript
class_name LoggieSystemSpecsMsg extends LoggieMsg
func embed_specs() -> LoggieSystemSpecsMsg:
func embed_essential_logger_specs() -> LoggieSystemSpecsMsg:
	var loggie = get_logger()
func embed_advanced_logger_specs() -> LoggieSystemSpecsMsg:
	var loggie = get_logger()
	var settings_dict = loggie.settings.to_dict()
		var setting_value = settings_dict[setting_var_name]
		var content_to_print = setting_value
func embed_system_specs() -> LoggieSystemSpecsMsg:
	var loggie = get_logger()
	var header = loggie.msg("Operating System: ").color(Color.ORANGE).add(OS.get_name()).box(4)
func embed_localization_specs() -> LoggieSystemSpecsMsg:
	var loggie = get_logger()
	var header = loggie.msg("Localization: ").color(Color.ORANGE).add(OS.get_locale()).box(7)
func embed_date_data() -> LoggieSystemSpecsMsg:
	var loggie = get_logger()
	var header = loggie.msg("Date").color(Color.ORANGE).box(15)
func embed_hardware_specs() -> LoggieSystemSpecsMsg:
	var loggie = get_logger()
	var header = loggie.msg("Hardware").color(Color.ORANGE).box(13)
func embed_video_specs() -> LoggieSystemSpecsMsg:
	const adapter_type_to_string = ["Other (Unknown)", "Integrated", "Discrete", "Virtual", "CPU"]
	var adapter_type_string = adapter_type_to_string[RenderingServer.get_video_adapter_type()]
	var video_adapter_driver_info = OS.get_video_adapter_driver_info()
	var loggie = get_logger()
	var header = loggie.msg("Video").color(Color.ORANGE).box(15)
func embed_display_specs() -> LoggieSystemSpecsMsg:
	const screen_orientation_to_string = [
	var screen_orientation_string = screen_orientation_to_string[DisplayServer.screen_get_orientation()]
	var loggie = get_logger()
	var header = loggie.msg("Display").color(Color.ORANGE).box(13)
func embed_audio_specs() -> LoggieSystemSpecsMsg:
	var loggie = get_logger()
	var header = loggie.msg("Audio").color(Color.ORANGE).box(14)
func embed_engine_specs() -> LoggieSystemSpecsMsg:
	var loggie = get_logger()
	var header = loggie.msg("Engine").color(Color.ORANGE).box(14)
func embed_input_specs() -> LoggieSystemSpecsMsg:
	var has_virtual_keyboard = DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD)
	var loggie = get_logger()
	var header = loggie.msg("Input").color(Color.ORANGE).box(14)
func embed_script_data(script : Script):
	var loggie = get_logger()
```

### `res:///addons/loggie/tools/loggie_tools.gd`
```gdscript
class_name LoggieTools extends Node
static func remove_BBCode(text: String, specific_tags = null) -> String:
	var default_tags = ["b", "i", "u", "s", "indent", "code", "url", "center", "right", "color", "bgcolor", "fgcolor"]
	var tags = specific_tags if specific_tags is Array else default_tags
	var regex = RegEx.new()
	var tags_pattern = "|".join(tags)
	var stripped_text = regex.sub(text, "", true)
static func concatenate_args(args : Array, custom_converter_fn : Variant = null) -> String:
	var converter_fn : Callable = LoggieTools.convert_to_string
	var final_msg : String = converter_fn.call(args[0])
		var arg = args[i]
		var is_not_followed_by_a_null_arg = true if (i + 1 <= args.size() - 1) and (args[i + 1] != null) else false
			var converted_arg : String = converter_fn.call(arg)
static func convert_BBCode_to_markdown(text: String) -> String:
	var unsupported_tags = ["indent", "url", "center", "right", "color", "bgcolor", "fgcolor"]
	var supported_conversions = {
static func convert_to_string(something : Variant) -> String:
	var result : String
static func convert_string_to_format_mode(str : String, mode : LoggieEnums.MsgFormatMode) -> String:
static func color_to_ANSI(color: Color) -> String:
	var r = int(color.r * 255)
	var g = int(color.g * 255)
	var b = int(color.b * 255)
static func rich_to_ANSI(text: String) -> String:
	var regex_color = RegEx.new()
		var match = regex_color.search(text)
		var color_str = match.get_string(1).to_upper()
		var color: Color
		var color_code: String
		var reset_code = "\u001b[0m"
		var replacement = color_code + match.get_string(2) + reset_code
	var bold_on = "\u001b[1m"
	var bold_off = "\u001b[22m"
	var italic_on = "\u001b[3m"
	var italic_off = "\u001b[23m"
	var regex_bbcode = RegEx.new()
static func get_current_stack_frame_data() -> Dictionary:
	var stack = get_stack()
		var pruned_stack = []
			var source : String = stack[index].source
			var prune_breakpoint_files = ["loggie", "loggie_message"]
static func get_class_name_from_script(path_or_script : Variant, proxy : LoggieEnums.NamelessClassExtensionNameProxy) -> String:
	var script
	var _class_name = ""
		var base_script = script.get_base_script()
static func extract_class_name_from_gd_script(path_or_script : Variant, proxy : LoggieEnums.NamelessClassExtensionNameProxy) -> String:
	var path : String
	var file = FileAccess.open(path, FileAccess.READ)
	var _class_name: String = ""
		var line = file.get_line().strip_edges()
		var script = load(path)
static func chunk_string(string : String, chunk_size : int) -> Array:
	var message_chunks = []
static func copy_dir_absolute(path_dir_to_copy: String, path_dir_to_copy_into: String, overwrite_existing_files_with_same_name : bool = false) -> Dictionary:
	const debug_enabled = false
	var result = {
	var source_dir = DirAccess.open(path_dir_to_copy)
		var open_error = DirAccess.get_open_error()
	var target_dir = DirAccess.open(path_dir_to_copy_into)
	var target_dir_path_abs = ProjectSettings.globalize_path(path_dir_to_copy_into)
		var msg = LoggieMsg.new("📂 Target directory not found - creating it at:").msg(path_dir_to_copy_into).color(Color.CADET_BLUE)
		var file_path_abs = ProjectSettings.globalize_path(path_dir_to_copy.path_join(file_name))
		var target_file_path_abs = target_dir_path_abs.path_join(file_name)
		var copying_msg = LoggieMsg.new("📝 Copying file...")
		var is_overwrite_required = false
			var copy_error = DirAccess.copy_absolute(file_path_abs, target_file_path_abs)
		var source_subdir_path = path_dir_to_copy.path_join(dir_name)
		var source_subdir_path_abs = ProjectSettings.globalize_path(source_subdir_path)
		var target_subdir_path = path_dir_to_copy_into.path_join(dir_name)
		var dir_path_abs = ProjectSettings.globalize_path(target_subdir_path)
		var make_dir_error = DirAccess.make_dir_recursive_absolute(dir_path_abs)
			var error_msg = LoggieMsg.new("Attempt to create directory at absolute path recursively failed with error: '", error_string(make_dir_error))
		var subdir_copy_result = copy_dir_absolute(source_subdir_path_abs, target_subdir_path, overwrite_existing_files_with_same_name)
```

### `res:///addons/loggie/version_management/loggie_update.gd`
```gdscript
class_name LoggieUpdate extends Node
signal failed()
signal succeeded()
signal progress(value : float)
signal status_changed(status_msg : Variant, substatus_msg : Variant)
signal starting()
signal is_in_progress_changed(new_value : bool)
const TEMP_FILES_DIR = "user://"
const ALT_LOGGIE_PLUGIN_CONTAINER_DIR = ""
const REPORTS_DOMAIN : String = "loggie_update_status_reports"
var _logger : Variant
var release_notes_url = ""
var prev_version : LoggieVersion = null
var new_version : LoggieVersion = null
var is_in_progress : bool = false
var _clean_up_backup_files : bool = true
func _init(_prev_version : LoggieVersion, _new_version : LoggieVersion) -> void:
func get_logger() -> Variant:
func set_release_notes_url(url : String) -> void:
func set_is_in_progress(value : bool) -> void:
func try_start():
		var github_data = self.new_version.get_meta("github_data")
func _start():
	var loggie = self.get_logger()
	var update_data = self.new_version.get_meta("github_data")
	var http_request = HTTPRequest.new()
func _on_download_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var loggie = self.get_logger()
	var LOGGIE_PLUGIN_CONTAINER_DIR = ALT_LOGGIE_PLUGIN_CONTAINER_DIR if !ALT_LOGGIE_PLUGIN_CONTAINER_DIR.is_empty() else loggie.get_directory_path().get_base_dir() + "/"
	var LOGGIE_PLUGIN_DIR = ProjectSettings.globalize_path(LOGGIE_PLUGIN_CONTAINER_DIR.path_join("loggie/"))
	var TEMP_ZIP_FILE_PATH = ProjectSettings.globalize_path(TEMP_FILES_DIR.path_join("_temp_loggie_{ver}.zip".format({"ver": str(new_version)})))
	var TEMP_PREV_VER_FILES_DIR_PATH = ProjectSettings.globalize_path(TEMP_FILES_DIR.path_join("_temp_loggie_{ver}_backup".format({"ver": str(prev_version)})))
	var clean_up : Callable = func():
	var revert_to_backup = func():
	var zip_file: FileAccess = FileAccess.open(TEMP_ZIP_FILE_PATH, FileAccess.WRITE)
	var copy_prev_ver_result = LoggieTools.copy_dir_absolute(LOGGIE_PLUGIN_DIR, TEMP_PREV_VER_FILES_DIR_PATH, true)
		var copy_prev_var_result_errors_msg = LoggieMsg.new("Errors encountered:")
	var zip_reader: ZIPReader = ZIPReader.new()
	var zip_reader_open_error = zip_reader.open(TEMP_ZIP_FILE_PATH)
	var files : PackedStringArray = zip_reader.get_files() 
	var base_path_in_zip = files[1] 
		var new_file_path: String = path.replace(base_path_in_zip, "")
			var abs_path = LOGGIE_PLUGIN_CONTAINER_DIR + new_file_path
			var file : FileAccess = FileAccess.open(abs_path, FileAccess.WRITE)
				var file_content = zip_reader.read_file(path)
	var CUSTOM_SETTINGS_IN_PREV_VER_PATH = TEMP_PREV_VER_FILES_DIR_PATH.path_join("custom_settings.gd")
		var CUSTOM_SETTINGS_IN_NEW_VER_PATH = ProjectSettings.globalize_path(LOGGIE_PLUGIN_DIR.path_join("custom_settings.gd"))
		var custom_settings_copy_error = DirAccess.copy_absolute(CUSTOM_SETTINGS_IN_PREV_VER_PATH, CUSTOM_SETTINGS_IN_NEW_VER_PATH)
	var CUSTOM_CHANNELS_IN_PREV_VER_PATH = ProjectSettings.globalize_path(TEMP_PREV_VER_FILES_DIR_PATH.path_join("channels/custom_channels/"))
		var CUSTOM_CHANNELS_IN_NEW_VER_PATH = ProjectSettings.globalize_path(LOGGIE_PLUGIN_DIR.path_join("channels/custom_channels/"))
		var copy_prev_ver_custom_channels_result = LoggieTools.copy_dir_absolute(CUSTOM_CHANNELS_IN_PREV_VER_PATH, CUSTOM_CHANNELS_IN_NEW_VER_PATH, true)
			var copy_prev_var_result_errors_msg = LoggieMsg.new("Errors encountered:")
func _success():
	var msg = "💬 You may see temporary errors in the console due to Loggie files being re-scanned and reloaded on the spot.\nIt should be safe to dismiss them, but for the best experience, reload the Godot editor (and the plugin, if something seems wrong).\n\n🚩 If you see a 'Files have been modified on disk' window pop up, choose 'Discard local changes and reload' to accept incoming changes."
		var editor_plugin = Engine.get_meta("LoggieEditorPlugin")
func _failure(status_msg : String):
	var loggie = self.get_logger()
func send_progress_update(progress_amount : float, status_msg : String, substatus_msg : String):
	var loggie = self.get_logger()
```

### `res:///addons/loggie/version_management/loggie_version.gd`
```gdscript
class_name LoggieVersion extends Resource
var minor : int = -1 ## The minor component of the version.
var major : int = -1 ## The major component of the version.
var proxy_for : LoggieVersion = null ## The version that this version is a proxy for. (Internal use only)
func _init(_major : int = -1, _minor : int = -1) -> void:
func _to_string() -> String:
func is_valid() -> bool:
func is_higher_than(version : LoggieVersion):
static func from_string(version_string : String) -> LoggieVersion:
	var version : LoggieVersion = LoggieVersion.new()
	var regex = RegEx.new()
	var result = regex.search(version_string)
```

### `res:///addons/loggie/version_management/loggie_version_manager.gd`
```gdscript
class_name LoggieVersionManager extends RefCounted
signal latest_version_updated()
signal update_ready()
const REMOTE_RELEASES_URL = "https://api.github.com/repos/Shiva-Shadowsong/loggie/releases"
const REPORTS_DOMAIN : String = "loggie_version_check_reports"
var version : LoggieVersion = null
var latest_version : LoggieVersion = null
var config : ConfigFile = ConfigFile.new()
var _logger : Variant = null
var _update : LoggieUpdate = null
var _version_proxy : LoggieVersion = null
func connect_logger(logger : Variant) -> void:
func get_logger() -> Variant:
func find_and_store_current_version():
	var detected_version = self._logger.version
func find_and_store_latest_version():
	var loggie = self.get_logger()
	var http_request = HTTPRequest.new()
func on_update_available_detected() -> void:
	var loggie = self.get_logger()
	var github_data = self.latest_version.get_meta("github_data")
	var latest_release_notes_url = github_data.html_url
	var hasUpdatedAlready = Engine.has_meta("LoggieUpdateSuccessful") and Engine.get_meta("LoggieUpdateSuccessful")
func _on_get_latest_version_request_completed(result : int, response_code : int, headers : PackedStringArray, body: PackedByteArray):
	var loggie = self.get_logger()
	var response = JSON.parse_string(body.get_string_from_utf8())
	var latest_version_data = response[0] # GitHub releases are in order of creation, so grab the first one from the response, that's the latest one.
func on_latest_version_updated() -> void:
	var loggie = self.get_logger()
func create_and_show_updater_widget(update : LoggieUpdate) -> Window:
	const PATH_TO_WIDGET_SCENE = "addons/loggie/version_management/update_prompt_window.tscn"
	var WIDGET_SCENE = load(PATH_TO_WIDGET_SCENE)
	var loggie = self.get_logger()
	var popup_parent = null
	var _popup = Window.new()
		var success_dialog = AcceptDialog.new()
		var msg = "💬 You may see temporary errors in the console due to Loggie files being re-scanned and reloaded on the spot.\nIt should be safe to dismiss them, but for the best experience, reload the Godot editor (and the plugin, if something seems wrong).\n\n🚩 If you see a 'Files have been modified on disk' window pop up, choose 'Discard local changes and reload' to accept incoming changes."
	var on_close_requested = func():
	var widget : LoggieUpdatePrompt = WIDGET_SCENE.instantiate()
func update_version_cache():
	var logger = self.get_logger()
func is_update_available() -> bool:
	var loggie = self.get_logger()
```

### `res:///addons/loggie/version_management/update_prompt_window.gd`
```gdscript
class_name LoggieUpdatePrompt extends Panel
signal close_requested()
@export var animator : AnimationPlayer
@export var host_window_size : Vector2 = Vector2(1063, 672)
var _logger : Variant
var _update : LoggieUpdate
var is_currently_updating : bool = false
func _ready() -> void:
func connect_to_update(p_update : LoggieUpdate) -> void:
func get_logger() -> Variant:
func is_update_in_progress_changed(is_in_progress : bool) -> void:
func connect_control_effects():
	var buttons_with_on_focushover_effect = [%OptionExitBtn, %OptionRestartGodotBtn, %OptionRetryUpdateBtn, %ReleaseNotesBtn, %RemindLaterBtn, %UpdateNowBtn]
			var editor_plugin = Engine.get_meta("LoggieEditorPlugin")
		var loggie = self.get_logger()
func refresh_remind_later_btn():
func on_update_starting():
func on_update_progress(value : float):
func on_update_succeeded():
func on_update_status_changed(status_msg : Variant, substatus_msg : Variant):
func on_update_failed():
func _on_button_focus_entered(button : Button):
		var old_tween = button.get_meta("scale_tween")
	var tween : Tween = button.create_tween()
func _on_button_focus_exited(button : Button):
		var old_tween = button.get_meta("scale_tween")
	var tween : Tween = button.create_tween()
```

### `res:///autoload/DynastyManager.gd`
```gdscript
extends Node
signal jarl_stats_updated(jarl_data: JarlData)
signal year_ended
var current_jarl: JarlData
var minimum_inherited_legitimacy: int = 0
var loaded_legacy_upgrades: Array[LegacyUpgradeData] = []
var active_year_modifiers: Dictionary[String, Variant] = {}
var current_year: int = 867 
enum Season { SPRING, SUMMER, AUTUMN, WINTER }
var current_season: Season = Season.SPRING
const USER_DYNASTY_PATH = "user://savegame_dynasty.tres"
const DEFAULT_JARL_PATH = "res://data/characters/PlayerJarl.tres"
func _ready() -> void:
func advance_season() -> void:
func _transition_to_season(new_season: Season) -> void:
	var names = ["Spring", "Summer", "Autumn", "Winter"]
	var s_name = names[current_season]
	var payout_report = EconomyManager.calculate_seasonal_payout(s_name)
			var warnings = SettlementManager.process_warband_hunger()
func _display_seasonal_feedback(season_name: String, payout: Dictionary) -> void:
	var center_screen = Vector2(960, 500)
	var color = Color.WHITE
	var offset_y = 40
		var amount = payout[res]
			var text = "+%d %s" % [amount, res.capitalize()]
			var pos = center_screen + Vector2(0, offset_y)
			var res_color = Color.WHITE
			var clean_msg = msg.replace("[color=green]", "").replace("[/color]", "")
			var pos = center_screen + Vector2(0, offset_y)
func get_current_season_name() -> String:
	var names = ["Spring", "Summer", "Autumn", "Winter"]
func _load_game_data() -> void:
func start_new_campaign() -> void:
func _load_legacy_upgrades_from_disk() -> void:
	var dir = DirAccess.open("res://data/legacy/")
		var file_name = dir.get_next()
				var path = "res://data/legacy/" + file_name
				var upgrade_data = load(path) as LegacyUpgradeData
					var unique_upgrade = upgrade_data.duplicate()
func get_current_jarl() -> JarlData:
func can_spend_authority(cost: int) -> bool:
func spend_authority(cost: int) -> bool:
func can_spend_renown(cost: int) -> bool:
func spend_renown(cost: int) -> bool:
func award_renown(amount: int) -> void:
func purchase_legacy_upgrade(upgrade_key: String) -> void:
func has_purchased_upgrade(upgrade_key: String) -> bool:
func add_conquered_region(region_path: String) -> void:
func has_conquered_region(region_path: String) -> bool:
func get_available_heir_count() -> int:
func designate_heir(target_heir: JarlHeirData) -> void:
func start_heir_expedition(heir: JarlHeirData, expedition_duration: int = 3) -> void:
func marry_heir_for_alliance(region_path: String) -> bool:
	var heir_to_marry = current_jarl.get_first_available_heir()
func is_allied_region(region_path: String) -> bool:
func add_trait_to_heir(heir: JarlHeirData, trait_data: JarlTraitData) -> void:
func find_heir_by_name(h_name: String) -> JarlHeirData:
func kill_heir_by_name(h_name: String, reason: String) -> void:
	var heir = find_heir_by_name(h_name)
func start_winter_cycle() -> void:
func end_winter_cycle_complete() -> void:
	var payout_report = EconomyManager.calculate_seasonal_payout("Winter")
func _process_heir_simulation() -> void:
	var heirs_to_remove: Array[JarlHeirData] = []
func _resolve_expedition(heir: JarlHeirData) -> void:
	var roll = randf()
		var renown_gain = randi_range(100, 300)
func _try_birth_event() -> void:
	var base_chance = 0.30
func _generate_new_baby() -> void:
	var baby = DynastyGenerator.generate_newborn()
func _save_jarl_data() -> void:
	var error = ResourceSaver.save(current_jarl, current_jarl.resource_path)
func debug_kill_jarl() -> void:
func _check_for_jarl_death() -> bool:
	var jarl = get_current_jarl()
	var death_chance = 0.0
func _trigger_succession() -> void:
	var old_jarl = current_jarl
	var heir = null
	var new_jarl = _promote_heir_to_jarl(heir, old_jarl)
	var ancestor_entry = {
	var succession_event_data = EventData.new() 
func _promote_heir_to_jarl(heir: JarlHeirData, predecessor: JarlData) -> JarlData:
	var new_jarl = JarlData.new()
	var new_legit = int(predecessor.legitimacy * 0.8)
func _on_succession_choices_made(renown_choice: String, gold_choice: String) -> void:
func perform_hall_action(cost: int = 1) -> bool:
func apply_year_modifier(key: String) -> void:
func _generate_oath_name() -> String:
	var names = ["Red", "Bold", "Young", "Wild", "Sworn", "Lucky"]
```

### `res:///autoload/EconomyManager.gd`
```gdscript
extends Node
const BUILDER_EFFICIENCY: int = 6 
const GATHERER_EFFICIENCY: int = 10 
const BASE_GATHERING_CAPACITY: int = 2
const FOOD_PER_PERSON_PER_YEAR: int = 10
const BASE_GROWTH_RATE: float = 0.02 
const STARVATION_PENALTY: float = -0.15 
const UNREST_PER_LANDLESS_PEASANT: int = 2
const FERTILITY_BONUS: float = 0.01
const BASE_LAND_CAPACITY: int = 5
const BASE_STEWARDSHIP_THRESHOLD: int = 10
const STEWARDSHIP_SCALAR: float = 0.05
const TRAIT_FERTILE: String = "Fertile"
const SEASON_AUTUMN: String = "Autumn"
const SEASON_WINTER: String = "Winter"
const WINTER_WOOD_DEMAND: int = 20 # Base fireplace cost
const BASE_STORAGE_CAPACITY: int = 200 
const BASE_GOLD_CAPACITY: int = 500
const RAID_LOSS_RATIO_MIN: float = 0.2
const RAID_LOSS_RATIO_MAX: float = 0.4
const RAID_BUILDING_DMG_MIN: int = 50
const RAID_BUILDING_DMG_MAX: int = 150
func get_resource_cap(resource_type: String) -> int:
	var settlement = SettlementManager.current_settlement
	var key = resource_type.to_lower()
	var cap = BASE_STORAGE_CAPACITY
			var data = load(entry["resource_path"])
				var bonus = data.get("storage_capacity_bonus")
					var b_type = data.resource_type.to_lower()
func is_storage_full(resource_type: String) -> bool:
	var settlement = SettlementManager.current_settlement
	var key = resource_type.to_lower()
	var current = settlement.treasury.get(key, 0)
	var cap = get_resource_cap(key)
func get_projected_income() -> Dictionary[String, int]:
	var settlement = SettlementManager.current_settlement
	var projection: Dictionary[String, int] = {}
	var stewardship_bonus := 1.0
	var jarl = DynastyManager.get_current_jarl()
		var skill = jarl.get_effective_skill("stewardship")
		var b_data = load(entry["resource_path"])
			var type = b_data.resource_type.to_lower()
			var p_count = entry.get("peasant_count", 0)
			var p_out = p_count * b_data.base_passive_output
			var t_count = entry.get("thrall_count", 0)
			var t_out = t_count * b_data.output_per_thrall
			var production = int((p_out + t_out) * stewardship_bonus)
			var r_data = load(region_path)
					var key = res.to_lower()
func get_winter_forecast() -> Dictionary[String, int]:
	var settlement = SettlementManager.current_settlement
	var pop = settlement.population_peasants
	var food_demand = pop * FOOD_PER_PERSON_PER_YEAR
	var wood_demand = WINTER_WOOD_DEMAND
func calculate_seasonal_payout(season_name: String) -> Dictionary:
	var settlement = SettlementManager.current_settlement
	var total_payout: Dictionary[String, Variant] = { "_messages": [] }
	var yearly_projection = get_projected_income()
		var yearly_amount = yearly_projection[res]
		var seasonal_amount = 0
				var msg_list: Array = total_payout["_messages"]
		var jarl = DynastyManager.get_current_jarl()
func _apply_payout_to_treasury(settlement: SettlementData, payout: Dictionary) -> void:
		var key = res.to_lower()
		var amount = payout[res]
		var cap = get_resource_cap(key)
		var current = settlement.treasury.get(key, 0)
		var space_left = cap - current
		var amount_to_add = clampi(amount, 0, max(0, space_left))
func _calculate_demographics(settlement: SettlementData, payout_report: Dictionary, jarl: JarlData) -> void:
	var pop = settlement.population_peasants
	var current_food = settlement.treasury.get("food", 0)
	var total_food_available = current_food 
	var food_required = pop * FOOD_PER_PERSON_PER_YEAR
	var growth_rate = BASE_GROWTH_RATE
	var event_msg = ""
		var food_consumed = food_required
	var net_change = int(pop * growth_rate)
	var pop_change_str = ""
	var msg_list: Array = payout_report["_messages"]
	var land_capacity = _calculate_total_land_capacity(settlement)
		var excess_men = settlement.population_peasants - land_capacity
		var unrest_gain = excess_men * UNREST_PER_LANDLESS_PEASANT
func _calculate_total_land_capacity(settlement: SettlementData) -> int:
	var total_cap = BASE_LAND_CAPACITY
		var data = load(entry["resource_path"]) as BuildingData
func deposit_resources(loot: Dictionary) -> void:
	var settlement = SettlementManager.current_settlement
		var amount = loot[res]
		var key = res.to_lower()
			var cap = get_resource_cap(key)
			var current = settlement.treasury.get(key, 0)
			var space = cap - current
			var to_add = min(amount, max(0, space))
func attempt_purchase(item_cost: Dictionary) -> bool:
	var settlement = SettlementManager.current_settlement
		var key = res.to_lower()
		var key = res.to_lower()
func apply_raid_damages() -> Dictionary:
	var settlement = SettlementManager.current_settlement
	var report = { "gold_lost": 0, "wood_lost": 0, "buildings_damaged": 0, "buildings_destroyed": 0 }
	var loss_ratio = randf_range(RAID_LOSS_RATIO_MIN, RAID_LOSS_RATIO_MAX)
	var g_loss = int(settlement.treasury.get("gold", 0) * loss_ratio)
	var w_loss = int(settlement.treasury.get("wood", 0) * loss_ratio)
	var indices_to_remove: Array[int] = []
		var entry = settlement.pending_construction_buildings[i]
			var dmg = randi_range(RAID_BUILDING_DMG_MIN, RAID_BUILDING_DMG_MAX)
func add_resources(resources: Dictionary) -> void:
```

### `res:///autoload/EventBus.gd`
```gdscript
extends Node
signal building_right_clicked(building: Node2D)
signal building_state_changed(building: BaseBuilding, new_state: int)
signal build_request_made(building_data: BuildingData, grid_position: Vector2i)
signal building_ready_for_placement(building_data: BuildingData)
signal building_placement_cancelled(building_data: BuildingData)
signal building_selected(building: BaseBuilding)
signal building_deselected()
signal request_worker_assignment(target_building: BaseBuilding)
signal request_worker_removal(target_building: BaseBuilding)
signal floating_text_requested(text: String, world_position: Vector2, color: Color)
signal pathfinding_grid_updated(grid_position: Vector2i)
signal treasury_updated(new_treasury: Dictionary)
signal purchase_successful(item_name: String)
signal purchase_failed(reason: String)
signal raid_loot_secured(type: String, amount: int)
signal scene_change_requested(scene_key: String)
signal world_map_opened()
signal raid_mission_started(target_type: String)
signal settlement_loaded(settlement_data: SettlementData)
signal player_unit_died(unit: Node2D)
signal player_unit_spawned(unit: Node2D)
signal worker_management_toggled()
signal dynasty_view_requested()
signal select_command(select_rect: Rect2, is_box_select: bool)
signal units_selected(units: Array) 
signal move_command(target_position: Vector2)
signal attack_command(target_node: Node2D)
signal formation_move_command(target_position: Vector2, direction_vector: Vector2)
signal interact_command(target: Node2D)
signal pillage_command(target_node: Node2D)
signal control_group_command(group_index: int, is_assigning: bool)
signal formation_change_command(formation_type: int)
signal event_system_finished()
signal succession_choices_made(renown_choice: String, gold_choice: String)
signal camera_input_lock_requested(is_locked: bool)
signal end_year_requested() # Legacy (Keep for now to avoid crashes)
signal advance_season_requested() # NEW: The primary time driver
signal season_changed(season_name: String) # NEW: Feedback for UI/World
signal seasonal_card_hovered(card: SeasonalCardResource)
signal seasonal_card_selected(card: SeasonalCardResource)
signal ui_request_phase_commit(phase_name: String, data: Dictionary)
signal ui_open_seasonal_screen(screen_type: String) # "spring", "summer", "autumn", "winter"
signal raid_launched(target_region: Resource, force_size: int)
signal autumn_resolved()
signal winter_ended()
```

### `res:///autoload/EventManager.gd`
```gdscript
extends Node
@export var event_ui_scene: PackedScene
@export var succession_crisis_scene: PackedScene
var event_ui: EventUI
var available_events: Array[EventData] = []
var fired_unique_events: Array[String] = []
const TRAIT_RIVAL = preload("res://data/traits/Trait_Rival.tres")
func _ready() -> void:
func initialize_event_system() -> void:
func _load_events_from_disk() -> void:
	var dir = DirAccess.open("res://data/events/")
		var file_name = dir.get_next()
				var path = "res://data/events/" + file_name
				var event_data = load(path) as EventData 
func _on_year_ended() -> void:
	var event_was_triggered: bool = _check_event_triggers()
func _check_event_triggers() -> bool:
	var jarl = DynastyManager.get_current_jarl()
func _check_conditions(event: EventData, jarl: JarlData) -> bool:
func _trigger_event(event_data: EventData) -> void:
func draw_dispute_card() -> DisputeEventData:
	var card = DisputeEventData.new()
func _on_choice_made(event: EventData, choice: EventChoice) -> void:
func _apply_event_consequences(event: EventData, choice: EventChoice) -> void:
			var heir = DynastyManager.get_current_jarl().get_first_available_heir()
```

### `res:///autoload/LogDomains.gd`
```gdscript
class_name LogDomains
const DYNASTY = "DYNASTY"
const SETTLEMENT = "SETTLEMENT"
const ECONOMY = "ECONOMY"
const EVENT = "EVENT"
const SCENE = "SCENE"
const RTS = "RTS"
const UNIT = "UNIT"
const AI = "AI"
const RAID = "RAID"
const MAP = "MAP"
const NAVIGATION = "NAVIGATION"
const UI = "UI"
const SYSTEM = "SYSTEM"
const BUILD = "BUILD"
const GAMEPLAY = "GAMEPLAY"
```

### `res:///autoload/NavigationManager.gd`
```gdscript
extends Node
signal navigation_grid_ready
const TILE_WIDTH = 64
const TILE_HEIGHT = 32
const TILE_HALF_SIZE = Vector2(32, 16)
const DIAGONAL_MODE = AStarGrid2D.DIAGONAL_MODE_ALWAYS 
const HEURISTIC = AStarGrid2D.HEURISTIC_EUCLIDEAN
const SMOOTHING_CHECK_RADIUS: float = 24.0 
const WALL_NUDGE_AMOUNT: float = 14.0 
var active_astar_grid: AStarGrid2D
var active_tilemap_layer: TileMapLayer
var _grid_rect: Rect2i
func _ready() -> void:
func _setup_base_grid() -> void:
func initialize_grid_from_tilemap(tilemap: TileMapLayer, map_size: Vector2i, tile_shape: Vector2i) -> void:
	var manual_rect = Rect2i(0, 0, map_size.x, map_size.y)
func register_map(map_layer: TileMapLayer, manual_rect: Rect2i = Rect2i()) -> void:
	var used_rect = manual_rect
func _sync_solids_from_map(map: TileMapLayer) -> void:
	var rect = active_astar_grid.region
			var coords = Vector2i(x, y)
			var tile_data = map.get_cell_tile_data(coords)
				var is_unwalkable = tile_data.get_custom_data("is_unwalkable")
func unregister_grid() -> void:
func get_astar_path(start_world: Vector2, end_world: Vector2, allow_partial: bool = true) -> PackedVector2Array:
	var start_grid = _world_to_grid(start_world)
	var end_grid = _world_to_grid(end_world)
	var path = active_astar_grid.get_point_path(start_grid, end_grid, allow_partial)
	var smoothed = _smooth_path(path)
	var nudged = _apply_wall_nudging(smoothed)
func _world_to_grid(pos: Vector2) -> Vector2i:
		var local = active_tilemap_layer.to_local(pos)
	var x_part = pos.x / TILE_HALF_SIZE.x
	var y_part = pos.y / TILE_HALF_SIZE.y
	var grid_x = floor((x_part + y_part) * 0.5)
	var grid_y = floor((y_part - x_part) * 0.5)
func _grid_to_world(grid: Vector2i) -> Vector2:
		var local = active_tilemap_layer.map_to_local(grid)
	var x = (grid.x - grid.y) * TILE_HALF_SIZE.x
	var y = (grid.x + grid.y) * TILE_HALF_SIZE.y
func request_valid_spawn_point(target_world_pos: Vector2, max_radius: int = 5) -> Vector2:
	var start_cell = _world_to_grid(target_world_pos)
				var check = start_cell + Vector2i(x, y)
func is_point_solid(grid_pos: Vector2i) -> bool:
func set_point_solid(grid_pos: Vector2i, is_solid: bool) -> void:
func snap_to_grid_center(world_pos: Vector2) -> Vector2:
	var grid = _world_to_grid(world_pos)
	var top_left = _grid_to_world(grid)
func _is_cell_within_bounds(grid_pos: Vector2i) -> bool:
func _is_point_solid_world(world_pos: Vector2) -> bool:
	var cell = _world_to_grid(world_pos)
func _smooth_path(path: PackedVector2Array) -> PackedVector2Array:
	var smoothed: PackedVector2Array = []
	var current_idx = 0
		var lookahead_limit = min(path.size() - 1, current_idx + 18)
		var check_idx = lookahead_limit
		var found_shortcut = false
func _has_thick_line_of_sight(from: Vector2, to: Vector2, radius: float) -> bool:
	var cell_size = active_astar_grid.cell_size
	var dist = from.distance_to(to)
	var step_size = min(cell_size.x, cell_size.y) / 2.0 
	var steps = ceil(dist / step_size)
	var direction = (to - from).normalized()
	var side_vector = Vector2(-direction.y, direction.x) * radius
		var center_pos = from + (direction * (i * step_size))
func _apply_wall_nudging(path: PackedVector2Array) -> PackedVector2Array:
	var nudged_path = path.duplicate()
		var point = path[i]
		var grid_pos = _world_to_grid(point)
		var repulsion = Vector2.ZERO
				var neighbor_cell = grid_pos + Vector2i(x, y)
					var push_dir = -Vector2(x, y).normalized() 
```

### `res:///autoload/PauseManager.gd`
```gdscript
extends Node
@export var pause_menu_scene: PackedScene
func _ready() -> void:
func _unhandled_input(event: InputEvent) -> void:
		var current_pause_state := get_tree().paused
func _pause_game() -> void:
		var error_msg := "PauseManager: 'pause_menu_scene' is not set in Project Settings!"
	var menu := pause_menu_scene.instantiate()
		var root_children := get_tree().root.get_children()
func request_pause() -> void:
func is_game_paused() -> bool:
	var paused := get_tree().paused
func on_game_unpaused() -> void:
```

### `res:///autoload/ProjectilePoolManager.gd`
```gdscript
extends Node
@export var projectile_scene: PackedScene = preload("res://scenes/effects/Projectile.tscn")
@export var initial_pool_size: int = 50
var available_projectiles: Array[Projectile] = []
var projectile_container: Node
func _ready() -> void:
		var p = projectile_scene.instantiate() as Projectile
func get_projectile() -> Projectile:
		var p = projectile_scene.instantiate() as Projectile
func return_projectile(projectile: Projectile) -> void:
```

### `res:///autoload/RaidManager.gd`
```gdscript
extends Node
signal raid_state_updated
var current_raid_target: SettlementData
var is_defensive_raid: bool = false
var current_raid_difficulty: int = 1
var pending_raid_result: RaidResultData = null
var outbound_raid_force: Array[WarbandData] = []
var raid_provisions_level: int = 1
var raid_health_modifier: float = 1.0
var last_raid_outcome: String = "neutral"
func reset_raid_state() -> void:
func prepare_raid_force(warbands: Array[WarbandData], provisions: int) -> void:
func set_current_raid_target(data: SettlementData) -> void:
func get_current_raid_target() -> SettlementData:
	var target = current_raid_target
func calculate_journey_attrition(target_distance: float) -> Dictionary:
	var jarl = DynastyManager.current_jarl
	var safe_range = jarl.get_safe_range()
	var report = {
	var base_risk = 0.02
	var roll = randf()
		var damage = 0.10 
func process_defensive_loss() -> Dictionary:
	var jarl = DynastyManager.current_jarl
	var aftermath_report = {
	var renown_loss = randi_range(50, 150)
	var material_losses = EconomyManager.apply_raid_damages()
		var victim = jarl.heirs.pick_random()
	var death_chance = 0.10
	var text = "Defeat! The settlement has been sacked.\n\n[color=salmon]Resources Lost:[/color]\n- %d Gold\n- %d Wood\n- %d Renown\n" % [material_losses.get("gold_lost", 0), material_losses.get("wood_lost", 0), renown_loss]
```

### `res:///autoload/SceneManager.gd`
```gdscript
extends Node
@export var settlement_scene: PackedScene
@export var world_map_scene: PackedScene
@export var raid_mission_scene: PackedScene
@export var winter_court_scene: PackedScene
func _ready() -> void:
func _on_scene_change_requested(scene_key: String) -> void:
	var target_scene: PackedScene = null
	var error = get_tree().change_scene_to_packed(target_scene)
```

### `res:///autoload/SettlementManager.gd`
```gdscript
extends Node
const USER_SAVE_PATH := "user://savegame.tres"
const MAP_SAVE_PATH := "user://campaign_map.tres"
const TILE_WIDTH = 64
const TILE_HEIGHT = 32
const TILE_HALF_SIZE = Vector2(TILE_WIDTH * 0.5, TILE_HEIGHT * 0.5)
const MAX_SEARCH_RADIUS: int = 10 # How far to search for valid ground
const UNWALKABLE_LAYER_NAME: String = "is_unwalkable" 
const GREAT_HALL_BUFFER: int = 4 # Tiles from water required for Great Hall
var current_settlement: SettlementData 
var active_map_data: SettlementData      
var active_building_container: Node2D = null
var active_tilemap_layer: TileMapLayer = null # Critical for Custom Data lookups
var pending_seasonal_recruits: Array[UnitData] = []
func _ready() -> void:
func is_terrain_walkable(coords: Vector2i) -> bool:
	var tile_data: TileData = active_tilemap_layer.get_cell_tile_data(coords)
	var is_unwalkable: bool = tile_data.get_custom_data(UNWALKABLE_LAYER_NAME)
func is_tile_valid_for_placement(coords: Vector2i) -> bool:
func get_nearest_valid_spawn_point(target_coords: Vector2i) -> Vector2i:
	var visited: Dictionary[Vector2i, bool] = {} # Typed dictionary for 4.4
	var queue: Array[Vector2i] = []
		var current: Vector2i = queue.pop_front()
		var neighbors = [
			var next_cell = current + offset
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var iso_x = (grid_pos.x - grid_pos.y) * 32.0 
	var iso_y = (grid_pos.x + grid_pos.y) * 16.0 
func get_tile_center(grid_pos: Vector2i) -> Vector2:
		var top_left = NavigationManager._grid_to_world(grid_pos)
func get_footprint_center(grid_pos: Vector2i, grid_size: Vector2i) -> Vector2:
	var center_x = float(grid_pos.x) + (float(grid_size.x) / 2.0)
	var center_y = float(grid_pos.y) + (float(grid_size.y) / 2.0)
	var iso_x = (center_x - center_y) * 32.0
	var iso_y = (center_x + center_y) * 16.0
func world_to_grid(pos: Vector2) -> Vector2i:
func is_tile_buildable(grid_pos: Vector2i) -> bool:
func get_active_grid_cell_size() -> Vector2:
func _spawn_building_node(building_data: BuildingData, grid_pos: Vector2i) -> BaseBuilding:
	var new_building = building_data.scene_to_spawn.instantiate()
	var center_pos = get_footprint_center(grid_pos, building_data.grid_size)
func place_building(building_data: BuildingData, grid_position: Vector2i, is_new_construction: bool = false) -> BaseBuilding:
	var new_building = _spawn_building_node(building_data, grid_position)
	var entry = {
func reconstruct_buildings_from_data() -> void:
			var data = load(entry.resource_path)
			var b = _spawn_building_node(data, entry.grid_position)
			var data = load(entry.resource_path)
			var b = _spawn_building_node(data, entry.grid_position)
func remove_building(building_instance: BaseBuilding) -> void:
	var grid_pos = Vector2i.ZERO
	var removed_placed = _remove_from_list(active_map_data.placed_buildings, grid_pos)
	var removed_pending = _remove_from_list(active_map_data.pending_construction_buildings, grid_pos)
func _update_building_footprint_navigation(data: BuildingData, origin: Vector2i, is_solid: bool) -> void:
			var cell = origin + Vector2i(x, y)
func _remove_from_list(list: Array, grid_pos: Vector2i) -> bool:
		var entry = list[i]
		var entry_pos = entry["grid_position"]
func is_placement_valid(grid_position: Vector2i, building_size: Vector2i, building_data: BuildingData = null) -> bool:
	var error = get_placement_error(grid_position, building_size, building_data)
func get_placement_error(grid_position: Vector2i, building_size: Vector2i, building_data: BuildingData = null) -> String:
			var check = grid_position + Vector2i(x, y)
			var res_name = building_data.resource_type.capitalize()
func _is_great_hall(data: BuildingData) -> bool:
func _check_surrounding_terrain_buffer(origin: Vector2i, size: Vector2i, buffer: int) -> bool:
	var start_x = origin.x - buffer
	var end_x = origin.x + size.x + buffer
	var start_y = origin.y - buffer
	var end_y = origin.y + size.y + buffer
func _is_within_district_range(grid_pos: Vector2i, size: Vector2i, data: EconomicBuildingData) -> bool:
	var cell = get_active_grid_cell_size()
	var center = get_footprint_center(grid_pos, size)
	var nodes = get_tree().get_nodes_in_group("resource_nodes")
				var dist = center.distance_to(node.global_position)
				var rad = node.get("district_radius") if "district_radius" in node else 300.0
func register_active_scene_nodes(container: Node2D) -> void:
func unregister_active_scene_nodes() -> void:
func load_settlement(data: SettlementData) -> void:
func _load_fallback_data(data: SettlementData) -> void:
func save_settlement() -> void:
	var error = ResourceSaver.save(current_settlement, USER_SAVE_PATH)
func delete_save_file() -> void:
func reset_manager_state() -> void:
func has_current_settlement() -> bool:
func deposit_resources(_resources: Dictionary) -> void:
func attempt_purchase(cost: Dictionary) -> bool:
func get_total_ship_capacity_squads() -> int:
	var total_capacity = 3
		var data = load(entry["resource_path"]) as BuildingData
func get_idle_peasants() -> int:
	var employed = 0
	var idle = current_settlement.population_peasants - employed
func get_idle_thralls() -> int:
	var employed = 0
	var idle = current_settlement.population_thralls - employed
func assign_worker(building_index: int, type: String, amount: int) -> void:
	var entry = current_settlement.placed_buildings[building_index]
	var data = load(entry["resource_path"]) as EconomicBuildingData
	var key = "peasant_count" if type == "peasant" else "thrall_count"
	var cap = data.peasant_capacity if type == "peasant" else data.thrall_capacity
	var current = entry.get(key, 0)
	var new_val = clampi(current + amount, 0, cap)
		var idle = get_idle_peasants() if type == "peasant" else get_idle_thralls()
func assign_construction_worker(index: int, type: String, amount: int) -> void:
	var entry = current_settlement.pending_construction_buildings[index]
	var data = load(entry["resource_path"]) as BuildingData
	var key = "peasant_count" if type == "peasant" else "thrall_count"
	var cap = data.base_labor_capacity 
	var current = entry.get(key, 0)
	var new_val = clampi(current + amount, 0, cap)
		var idle = get_idle_peasants() if type == "peasant" else get_idle_thralls()
func _validate_employment_levels() -> void:
	var total_peasants = current_settlement.population_peasants
	var employed_peasants = 0
		var deficit = employed_peasants - total_peasants
	var total_thralls = current_settlement.population_thralls
	var employed_thralls = 0
		var deficit = employed_thralls - total_thralls
func _force_layoffs(type: String, amount_to_remove: int) -> void:
	var removed_count = 0
	var key = "peasant_count" if type == "peasant" else "thrall_count"
	var buildings = current_settlement.placed_buildings
		var entry = buildings[i]
		var current_workers = entry.get(key, 0)
			var take = min(current_workers, amount_to_remove - removed_count)
func process_construction_labor() -> void:
	var completed_indices: Array[int] = []
		var entry = current_settlement.pending_construction_buildings[i]
		var b_data = load(entry["resource_path"]) as BuildingData
		var peasants = entry.get("peasant_count", 0)
		var thralls = entry.get("thrall_count", 0)
		var labor_points = (peasants + thralls) * EconomyManager.BUILDER_EFFICIENCY
func recruit_unit(unit_data: UnitData) -> void:
	var current_squads = current_settlement.warbands.size()
	var max_squads = get_total_ship_capacity_squads()
	var new_warband = WarbandData.new(unit_data)
func upgrade_warband_gear(warband: WarbandData) -> bool:
	var cost = warband.get_gear_cost()
func toggle_hearth_guard(warband: WarbandData) -> void:
func process_warband_hunger() -> Array[String]:
	var deserters: Array[WarbandData] = []
	var warnings: Array[String] = []
		var decay = 25
func _on_player_unit_died(unit: Node2D) -> void:
	var warband = unit.get("warband_ref")
func assign_worker_from_unit(building: BaseBuilding, type: String) -> bool:
	var entry = _find_entry_for_building(building)
	var data = building.data
	var cap = 0
	var current = 0
func _find_entry_for_building(building: BaseBuilding) -> Dictionary:
		var tagged_pos = building.grid_coordinate
	var grid_pos = NavigationManager._world_to_grid(building.global_position)
func unassign_worker_from_building(building: BaseBuilding, type: String) -> bool:
	var entry = _find_entry_for_building(building)
	var key = "peasant_count" if type == "peasant" else "thrall_count"
	var current = entry.get(key, 0)
func get_building_index(building_instance: Node2D) -> int:
	var data_to_search = active_map_data if active_map_data else current_settlement
	var search_placed = true
	var target_list = data_to_search.placed_buildings if search_placed else data_to_search.pending_construction_buildings
		var tagged_pos = building_instance.get("grid_coordinate")
				var entry = target_list[i]
				var pos = entry["grid_position"]
	var grid_pos = NavigationManager._world_to_grid(building_instance.global_position)
		var entry = target_list[i]
		var pos = entry["grid_position"]
func queue_seasonal_recruit(unit_data: UnitData, count: int) -> void:
func commit_seasonal_recruits() -> void:
	var new_warbands: Array[WarbandData] = []
	var current_batch_wb: WarbandData = null
func _generate_oath_name() -> String:
	var names = ["Red", "Bold", "Young", "Wild", "Sworn", "Lucky"]
func validate_formation_point(target_pos: Vector2, taken_grid_points: Array[Vector2i] = []) -> Vector2:
	var grid_pos = world_to_grid(target_pos)
	var safe_grid_pos = _get_closest_walkable_point_exclusive(grid_pos, 4, taken_grid_points)
func _get_closest_walkable_point_exclusive(origin: Vector2i, max_radius: int, exclusions: Array[Vector2i]) -> Vector2i:
				var candidate = origin + Vector2i(x, y)
```

### `res:///autoload/WinterManager.gd`
```gdscript
extends Node
signal winter_started
signal winter_ended
enum WinterSeverity { MILD, NORMAL, HARSH }
@export_group("Probabilities")
@export_range(0.0, 1.0) var harsh_chance: float = 0.20
@export_range(0.0, 1.0) var mild_chance: float = 0.05
@export_group("Multipliers")
@export var harsh_multiplier: float = 1.5
@export var mild_multiplier: float = 0.75
var current_severity: WinterSeverity = WinterSeverity.NORMAL
var winter_consumption_report: Dictionary = {}
var winter_upkeep_report: Dictionary = {} 
var winter_crisis_active: bool = false
func start_winter_phase() -> void:
func end_winter_phase() -> void:
func calculate_winter_demand(settlement: SettlementData) -> Dictionary:
	var mult: float = 1.0
	var base_food = (settlement.population_peasants * 1) + (settlement.warbands.size() * 5)
	var base_wood = 20
	var final_food = int(base_food * mult)
	var final_wood = int(base_wood * mult)
func _calculate_winter_needs() -> void:
	var settlement = SettlementManager.current_settlement
	var demand_report = calculate_winter_demand(settlement)
	var food_cost = demand_report["food_demand"]
	var wood_cost = demand_report["wood_demand"]
	var food_stock = settlement.treasury.get("food", 0)
	var wood_stock = settlement.treasury.get("wood", 0)
	var food_deficit = max(0, food_cost - food_stock)
	var wood_deficit = max(0, wood_cost - wood_stock)
func _apply_winter_consumption() -> void:
	var settlement = SettlementManager.current_settlement
	var f_cost = winter_consumption_report.get("food_cost", 0)
	var w_cost = winter_consumption_report.get("wood_cost", 0)
func _apply_environmental_decay() -> void:
	var decay = 0.2
		var current = SettlementManager.current_settlement.fleet_readiness
func resolve_crisis_with_gold() -> bool:
	var total_gold_cost = (winter_consumption_report["food_deficit"] * 5) + (winter_consumption_report["wood_deficit"] * 5)
func resolve_crisis_with_sacrifice(sacrifice_type: String) -> bool:
	var settlement = SettlementManager.current_settlement
			var deaths = max(1, int(winter_consumption_report["food_deficit"] / 5))
func _roll_severity() -> void:
	var roll = randf()
func _get_empty_report() -> Dictionary:
```

### `res:///data/buildings/Base_Building.gd`
```gdscript
class_name BaseBuilding
extends StaticBody2D
signal building_destroyed(building: BaseBuilding)
signal construction_completed(building: BaseBuilding)
signal loot_stolen(type: String, amount: int)
signal loot_depleted(building: BaseBuilding)
var grid_coordinate: Vector2i = Vector2i(-999, -999)
enum BuildingState { 
@export var data: BuildingData:
var current_health: int = 100
var current_state: BuildingState = BuildingState.ACTIVE 
var construction_progress: int = 0
var sprite: Sprite2D
var iso_placeholder: Node2D # Reference to the procedural shape
var hud: BuildingInfoHUD
const HUD_SCENE = preload("res://ui/components/BuildingInfoHUD.tscn")
var collision_shape: CollisionShape2D
var hitbox_area: Area2D
var attack_ai: Node = null 
var available_loot: Dictionary = {}
var total_loot_value: int = 0
func _ready() -> void:
func _setup_visual_style() -> void:
		var script = load("res://scripts/utility/IsoPlaceholder.gd")
func _initialize_loot() -> void:
	var eco = data as EconomicBuildingData
	var type = eco.resource_type
	var amount = eco.base_passive_output * 3
func steal_resources(max_amount: int) -> int:
	var target_res = ""
	var available = available_loot[target_res]
	var actual_steal = min(available, max_amount)
func _apply_data_and_scale() -> void:
		var cell_size = Vector2(64, 32) # Default
		var total_w = (data.grid_size.x + data.grid_size.y) * (cell_size.x * 0.5)
		var total_h = (data.grid_size.x + data.grid_size.y) * (cell_size.y * 0.5)
func set_state(new_state: BuildingState) -> void:
	var old_state = current_state
		construction_completed.emit(self)
func _update_visual_state() -> void:
func _update_logic_state() -> void:
func add_construction_progress(amount: int) -> void:
	construction_progress += amount
func take_damage(amount: int, _attacker: Node2D = null) -> void:
func die() -> void:
func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
func _create_hitbox() -> void:
	var s = CollisionShape2D.new()
func _setup_defensive_ai() -> void:
```

### `res:///data/buildings/BuildingData.gd`
```gdscript
class_name BuildingData
extends Resource
@export var display_name: String = "New Building"
@export_multiline var description: String = "A useful structure."
@export var scene_to_spawn: PackedScene
@export var icon: Texture2D
@export var building_texture: Texture2D
@export var build_cost: Dictionary
@export var max_health: int = 100
@export var blocks_pathfinding: bool = true
@export var grid_size: Vector2i = Vector2i.ONE
@export var dev_color: Color = Color.GRAY
@export var is_player_buildable: bool = false
@export_group("Construction")
@export var construction_effort_required: int = 100
@export var base_labor_capacity: int = 3
@export_group("Territory & Expansion")
@export var is_territory_hub: bool = false
@export var extends_territory: bool = false
@export var territory_radius: int = 4
@export var fleet_capacity_bonus: int = 0
@export_group("Demographics")
@export var arable_land_capacity: int = 0 
@export_group("Defensive Stats")
@export var is_defensive_structure: bool = false
@export var attack_damage: int = 5
@export var attack_range: float = 200.0
@export var attack_speed: float = 1.0
@export var ai_component_scene: PackedScene
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 400.0
```

### `res:///data/buildings/EconomicBuildingData.gd`
```gdscript
class_name EconomicBuildingData
extends BuildingData
@export_group("Thrall Economy")
@export var resource_type: String = "wood"
@export var base_passive_output: int = 50
@export var output_per_thrall: int = 50
@export var thrall_capacity: int = 5
@export var peasant_capacity: int = 5
@export var storage_capacity_bonus: int = 0
```

### `res:///data/characters/JarlData.gd`
```gdscript
class_name JarlData
extends Resource
@export var display_name: String = "New Jarl"
@export var portrait: Texture2D
@export var age: int = 25
@export var gender: String = "Male" # "Male", "Female"
@export_group("Dynasty & Authority")
@export var renown: int = 0
@export var renown_tier: int = 0
@export var current_authority: int = 3
@export var max_authority: int = 3
@export var years_since_action: int = 0
@export var legitimacy: int = 20
@export var succession_debuff_years_remaining: int = 0
@export_group("Lineage History")
@export var ancestors: Array[Dictionary] = []
@export var heir_starting_renown_bonus: int = 0
@export var purchased_legacy_upgrades: Array[String] = []
@export var conquered_regions: Array[String] = []
@export var allied_regions: Array[String] = []
@export_group("Naval Logistics")
@export var safe_naval_range: float = 600.0
@export var attrition_per_100px: float = 0.10
@export_group("Base Skills")
@export var command: int = 10
@export var diplomacy: int = 10
@export var stewardship: int = 10
@export var learning: int = 10
@export var prowess: int = 10
@export var charisma: int = 10
@export_group("Traits")
@export var traits: Array[JarlTraitData] = []
@export var legacy_trait_names: Array[String] = []
@export var is_wounded: bool = false
@export var wound_recovery_turns: int = 0
@export_group("Family & Succession")
@export var spouse_name: String = ""
@export var heirs: Array[JarlHeirData] = []
@export_group("Political Status")
@export var title: String = "Jarl"
@export var vassal_count: int = 0
@export var reputation: int = 0
@export var is_in_exile: bool = false
@export_group("Combat & Mission State")
@export var is_on_mission: bool = false
@export var battles_fought: int = 0
@export var battles_won: int = 0
@export var successful_raids: int = 0
@export var offensive_wins: int = 0 
@export_group("Winter Court")
var current_hall_actions: int = 0
var max_hall_actions: int = 0
func calculate_hall_actions() -> void:
	var score = stewardship + charisma 
func get_safe_range() -> float:
func get_available_heir_count() -> int:
	var count = 0
func get_first_available_heir() -> JarlHeirData:
func remove_heir(heir_to_remove: JarlHeirData) -> bool:
func check_has_valid_heir() -> bool:
func get_effective_skill(skill_name: String) -> int:
	var base_value: int = 0
	var trait_modifier: int = 0
func add_trait(trait_data: JarlTraitData) -> void:
func has_trait(trait_name: String) -> bool:
func get_authority_cap() -> int:
func can_take_action(authority_cost: int = 1) -> bool:
func spend_authority(cost: int = 1) -> bool:
func award_renown(amount: int) -> void:
func _update_renown_tier() -> void:
func reset_authority() -> void:
		var legit_multiplier = legitimacy / 100.0
		var authority_gained = int(round(max_authority * legit_multiplier))
func age_jarl(years: int = 1) -> void:
func remove_trait(trait_name: String) -> bool:
```

### `res:///data/characters/JarlHeirData.gd`
```gdscript
class_name JarlHeirData
extends Resource
enum HeirStatus {
@export_group("Identity")
@export var display_name: String = "New Heir"
@export var age: int = 16
@export var gender: String = "Male" # "Male", "Female"
@export var portrait: Texture2D
@export var is_designated_heir: bool = false
@export_group("Status")
@export var status: HeirStatus = HeirStatus.Available
@export var expedition_years_remaining: int = 0
@export_group("Skills & Traits")
@export var command: int = 8
@export var stewardship: int = 8
@export var learning: int = 8
@export var prowess: int = 8
@export var traits: Array[JarlTraitData] = []
@export var genetic_trait: JarlTraitData
```

### `res:///data/events/DisputeEventData.gd`
```gdscript
class_name DisputeEventData
extends Resource
@export_group("Narrative")
@export var title: String = "Dispute Title"
@export_multiline var description: String = "Description of the conflict."
@export_group("Costs")
@export var gold_cost: int = 100
@export var renown_cost: int = 25
@export var bans_unit: bool = false
@export_group("Consequences")
@export var penalty_modifier_key: String = ""
@export var penalty_description: String = "Recruitment costs double next year."
```

### `res:///data/events/EventChoice.gd`
```gdscript
class_name EventChoice
extends Resource
@export var choice_text: String = "Choice Text"
@export var tooltip_text: String = "Tooltip"
@export var effect_key: String = ""
```

### `res:///data/events/EventData.gd`
```gdscript
class_name EventData
extends Resource
@export_group("Event Display")
@export var title: String = "An Event Occurs"
@export_multiline var description: String = "Event description..."
@export var portrait: Texture2D
@export_group("Event Triggering")
@export var event_id: String = "unique_event_id"
@export var is_unique: bool = true
@export var base_chance: float = 0.5
@export var prerequisites: Array[String] = []
@export_group("Event Conditions")
@export var min_stewardship: int = -1
@export var min_command: int = -1
@export var min_prowess: int = -1
@export var min_renown: int = -1
@export var must_have_trait: String = ""
@export var must_not_have_trait: String = ""
@export var min_available_heirs: int = -1
@export var min_conquered_regions: int = -1
@export_group("Event Choices")
@export var choices: Array[EventChoice] = []
```

### `res:///data/legacy/LegacyUpgradeData.gd`
```gdscript
class_name LegacyUpgradeData
extends Resource
@export var display_name: String = "New Legacy Upgrade"
@export var icon: Texture2D
@export_multiline var description: String = "A permanent dynasty upgrade."
@export var renown_cost: int = 100
@export var authority_cost: int = 1
@export_group("Progress")
@export var required_progress: int = 1
@export var current_progress: int = 0
@export var effect_key: String = ""
@export var prerequisite_key: String = ""
var is_purchased: bool:
```

### `res:///data/missions/RaidLootData.gd`
```gdscript
extends Resource
class_name RaidLootData
@export var collected_loot: Dictionary = {}
func _init() -> void:
func add_loot(resource_type: String, amount: int) -> void:
func add_loot_from_building(building_data: BuildingData) -> void:
		var eco_data: EconomicBuildingData = building_data
		var loot_amount = eco_data.base_passive_output * 3
func get_total_loot() -> Dictionary:
func clear_loot() -> void:
func get_loot_summary() -> String:
	var summary_parts: Array[String] = []
			var display_name = GameResources.get_display_name(resource_type)
```

### `res:///data/missions/RaidResultData.gd`
```gdscript
class_name RaidResultData
extends Resource
@export var loot: Dictionary = {}
@export var casualties: Array[UnitData] = []
@export var outcome: String = "neutral" 
@export var victory_grade: String = "Standard"
@export var renown_earned: int = 0
```

### `res:///data/resources/SeasonalCardResource.gd`
```gdscript
class_name SeasonalCardResource
extends Resource
enum SeasonType { SPRING, WINTER }
@export_group("Classification")
@export var season: SeasonType = SeasonType.SPRING
@export_group("Display")
@export var title: String = "Card Title"
@export_multiline var description: String = "Effect description..."
@export var icon: Texture2D
@export_group("Costs (Winter)")
@export var cost_ap: int = 0
@export var cost_gold: int = 0
@export var cost_food: int = 0
@export_group("Effects (Spring/Strategic)")
@export var modifier_key: String = ""
@export var grant_gold: int = 0
@export var grant_renown: int = 0
```

### `res:///data/settlements/SettlementData.gd`
```gdscript
extends Resource
class_name SettlementData
@export var treasury: Dictionary = {
@export var placed_buildings: Array[Dictionary] = []
@export var pending_construction_buildings: Array = []
@export var warbands: Array[WarbandData] = []
@export var max_garrison_bonus: int = 0
@export var map_seed: int = 0
@export var population_peasants: int = 10 # Free Peasants
@export var population_thralls: int = 5 # Captive Workers
@export var worker_assignments: Dictionary = {}
@export var has_stability_debuff: bool = false
@export var unrest: int = 0 # 0-100 scale. 100 = Rebellion.
@export_group("Naval State")
@export var fleet_readiness: float = 1.0 
func get_fleet_capacity() -> int:
	var capacity = 2 # Base capacity (2 Warbands)
		var res_path = entry["resource_path"]
```

### `res:///data/traits/JarlTraitData.gd`
```gdscript
class_name JarlTraitData
extends Resource
@export var display_name: String = ""
@export var description: String = ""
@export var is_visible: bool = true # Should the player/AI know about this trait?
@export_group("Skill Modifiers")
@export var command_modifier: int = 0
@export var stewardship_modifier: int = 0
@export var intrigue_modifier: int = 0
@export_group("Macro Modifiers")
@export var renown_per_year_modifier: float = 0.0 # Used for passive Renown gain/loss
@export var vassal_opinion_modifier: int = 0  # Global change to vassal opinion of Jarl
@export var alliance_cost_modifier: float = 1.0 # Multiplier for alliance Authority cost
@export_group("Behavior Flags")
@export var is_wounded_trait: bool = false # e.g., Maimed, Crippled
@export var is_dishonorable_trait: bool = false # e.g., Betrayer, Cowardly
```

### `res:///data/units/UnitData.gd`
```gdscript
class_name UnitData
extends Resource
@export var display_name: String = "New Unit"
@export_file("*.tscn") var scene_path: String = ""
@export var scene_to_spawn: PackedScene 
@export var icon: Texture2D
@export var spawn_cost: Dictionary = {"food": 25}
@export_group("Combat Stats")
@export var max_health: int = 50
@export var move_speed: float = 75.0
@export var attack_damage: int = 8
@export var attack_speed: float = 1.2
@export var attack_range: float = 15.0 
@export var building_attack_range: float = 45.0
@export_group("Inventory & Logistics")
@export var max_loot_capacity: int = 100 
@export var encumbrance_speed_penalty: float = 0.5 # 50% slow at max load
@export_group("Visuals")
@export var visual_texture: Texture2D
@export var target_pixel_size: Vector2 = Vector2(32, 32)
@export_group("Movement Feel")
@export var acceleration: float = 10.0
@export var linear_damping: float = 5.0
@export_group("Raid Stats")
@export var pillage_speed: int = 10 
@export var burn_renown: int = 10
@export var ai_component_scene: PackedScene
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 400.0
@export_group("Social Stats")
@export var wergild_cost: int = 50
func load_scene() -> PackedScene:
```

### `res:///data/units/WarbandData.gd`
```gdscript
class_name WarbandData
extends Resource
@export var custom_name: String = "New Warband"
@export var unit_type: UnitData
@export var experience: int = 0
const XP_PER_LEVEL: int = 100
const MAX_LEVEL: int = 5
@export var gear_tier: int = 0
const MAX_GEAR_TIER: int = 3
@export var assigned_heir_name: String = ""
@export var loyalty: int = 100
@export var turns_idle: int = 0
@export var current_manpower: int = 10
const MAX_MANPOWER: int = 10
@export var is_hearth_guard: bool = false
@export var is_bondi: bool = false
@export var is_seasonal: bool = false
@export var is_wounded: bool = false
@export var battles_survived: int = 0
@export var history_log: Array[String] = []
func _init(p_unit_type: UnitData = null) -> void:
func add_history(entry: String) -> void:
func get_level() -> int:
func get_level_title() -> String:
	var lvl = get_level()
func get_stat_multiplier() -> float:
	var lvl = get_level()
func get_gear_cost() -> int:
func get_gear_name() -> String:
func get_gear_health_mult() -> float:
func get_gear_damage_mult() -> float:
func get_loyalty_description(jarl_name: String) -> String:
func modify_loyalty(amount: int) -> void:
func _generate_warband_name(_base_name: String) -> String:
	var prefixes = ["Iron", "Blood", "Storm", "Night", "Wolf", "Bear", "Raven"]
	var suffixes = ["Guard", "Raiders", "Blades", "Shields", "Hunters", "Fists"]
```

### `res:///data/world_map/MapState.gd`
```gdscript
class_name MapState
extends Resource
@export var region_data_map: Dictionary = {}
@export var turns_elapsed: int = 0
```

### `res:///data/world_map/RaidTargetData.gd`
```gdscript
class_name RaidTargetData
extends Resource
@export var display_name: String = "Monastery"
@export_multiline var description: String = "A small, undefended religious site."
@export var settlement_data: SettlementData
@export_group("Raid Costs")
@export var raid_cost_authority: int = 1
@export var authority_cost_override: int = -1
@export var difficulty_rating: int = 1 # 1-5 Stars
@export_group("Victory Conditions")
@export var par_time_seconds: int = 300 
@export var decisive_casualty_limit: int = 2
```

### `res:///data/world_map/WorldRegionData.gd`
```gdscript
class_name WorldRegionData
extends Resource
@export var display_name: String = "New Region"
@export_multiline var description: String = "A description of this region."
@export var raid_targets: Array[RaidTargetData] = []
@export var region_type_tag: String = "Province"
@export var yearly_income: Dictionary = {"gold": 10}
@export var base_authority_cost: int = 1
```

### `res:///player/RTSCamera.gd`
```gdscript
extends Camera2D
class_name RTSCamera
@export_group("Movement")
@export var camera_speed: float = 400.0
@export var edge_pan_margin: float = 20.0
@export var enable_edge_panning: bool = true
@export var enable_wasd_movement: bool = true
@export var enable_drag_panning: bool = true
@export_group("Zoom")
@export var min_zoom: float = 0.5  # Far away
@export var max_zoom: float = 2.0  # Close up
@export var zoom_speed: float = 0.25 # Clean snapping for pixel art
@export var zoom_smoothing: float = 10.0
@export_group("Bounds")
@export var bounds_enabled: bool = true
@export var bounds_rect: Rect2 = Rect2(-1000, -1000, 3000, 2500)
var target_zoom: Vector2 = Vector2.ONE
var is_dragging: bool = false
var drag_start_mouse_pos: Vector2 = Vector2.ZERO
var drag_start_camera_pos: Vector2 = Vector2.ZERO
var input_locked: bool = false
func _ready() -> void:
func _unhandled_input(event: InputEvent) -> void:
		var current_mouse_pos = get_viewport().get_mouse_position()
		var mouse_delta = drag_start_mouse_pos - current_mouse_pos
func _process(delta: float) -> void:
func _handle_keyboard_movement(delta: float) -> void:
	var movement_vector := Vector2.ZERO
	var viewport_size = get_viewport().get_visible_rect().size
	var mouse_pos = get_viewport().get_mouse_position()
		var zoom_multiplier = 1.0 / zoom.x
func _zoom_in() -> void:
func _zoom_out() -> void:
func _clamp_zoom() -> void:
func _clamp_position() -> void:
func _on_input_lock_requested(locked: bool) -> void:
```

### `res:///player/RTSController.gd`
```gdscript
extends Node
class_name RTSController
var selected_units: Array[BaseUnit] = []
var controllable_units: Array[BaseUnit] = []
var current_formation: SquadFormation.FormationType = SquadFormation.FormationType.LINE
var control_groups: Dictionary = {
func _ready() -> void:
func _emit_selection_update() -> void:
func _on_interact_command(target: Node2D) -> void:
func _on_move_command(target_position: Vector2) -> void:
func _on_formation_move_command(target_position: Vector2, direction_vector: Vector2) -> void:
func _handle_movement_logic(target_pos: Vector2, direction: Vector2) -> void:
	var soldiers: Array[Node2D] = []
	var civilians: Array[Node2D] = []
func _move_group_in_formation(unit_list: Array[Node2D], target: Vector2, direction: Vector2) -> void:
	var formation = SquadFormation.new(unit_list)
func _move_civilians_as_mob(unit_list: Array[Node2D], target: Vector2) -> void:
	var unit_count = unit_list.size()
	var mob_radius = sqrt(unit_count) * 20.0 
		var angle = randf() * TAU
		var distance = randf() * mob_radius
		var offset = Vector2(cos(angle), sin(angle)) * distance
		var specific_dest = target + offset
func add_unit_to_group(unit: Node2D) -> void:
func remove_unit(unit: BaseUnit) -> void:
	var was_selected = unit in selected_units
	var unit_id = unit.get_instance_id()
func _on_select_command(select_rect: Rect2, is_box_select: bool) -> void:
	var main_camera: Camera2D = get_viewport().get_camera_2d()
		var camera_pos = main_camera.get_screen_center_position()
		var camera_zoom = main_camera.zoom
		var viewport_size = get_viewport().get_visible_rect().size
		var world_rect_min = camera_pos - (viewport_size / (2.0 * camera_zoom)) + (select_rect.position / camera_zoom)
		var world_rect_max = world_rect_min + (select_rect.size / camera_zoom)
		var world_rect = Rect2(world_rect_min, world_rect_max - world_rect_min)
		var click_world_pos := main_camera.get_global_mouse_position()
		var closest_leader: BaseUnit = null
		var min_dist_sq = INF
		var click_radius_sq = 40 * 40
			var dist_sq = _get_closest_distance_to_squad(unit, click_world_pos)
func _is_squad_in_rect(unit: BaseUnit, rect: Rect2) -> bool:
func _get_closest_distance_to_squad(unit: BaseUnit, point: Vector2) -> float:
	var min_d = unit.global_position.distance_squared_to(point)
				var d = soldier.global_position.distance_squared_to(point)
func _on_attack_command(target_node: Node2D) -> void:
func command_scramble(target_position: Vector2) -> void:
		var panic_offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
		var unique_dest = target_position + panic_offset
func _validate_selection() -> void:
	var valid_units: Array[BaseUnit] = []
func _clear_selection() -> void:
func _on_control_group_command(group_index: int, is_assigning: bool) -> void:
func _on_formation_change_command(formation_type: int) -> void:
func _set_control_group(num: int) -> void:
func _select_control_group(num: int) -> void:
	var new_group_ids = control_groups[num]
		var unit = instance_from_id(unit_id) as BaseUnit
func _prune_dead_units() -> void:
	var alive_units: Array[BaseUnit] = []
func _on_pillage_command(target_node: Node2D) -> void:
```

### `res:///scenes/components/AttackAI.gd`
```gdscript
class_name AttackAI
extends Node2D
signal attack_started(target: Node2D)
signal attack_stopped()
signal about_to_attack(target: Node2D, damage: int)
enum AI_Mode { DEFAULT, DEFENSIVE_SIEGE }
@export var ai_mode: AI_Mode = AI_Mode.DEFAULT
@export var great_hall_los_range: float = 600.0
@export var attack_damage: int = 10
@export var attack_range: float = 200.0
@export var attack_speed: float = 1.0 
@export var projectile_scene: PackedScene
var building_attack_range: float = 45.0
var target_collision_mask: int = 0
var projectile_speed: float = 400.0
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_timer: Timer = $AttackTimer
var parent_node: Node2D
var current_target: Node2D = null
var targets_in_range: Array[Node2D] = []
var is_attacking: bool = false
func _ready() -> void:
func _setup_ai() -> void:
			var s = detection_area.get_child(0) as CollisionShape2D
func configure_from_data(data) -> void:
func set_target_mask(mask: int) -> void:
func force_target(target: Node2D) -> void:
	var actual_target = target
func stop_attacking() -> void:
func _on_target_entered(body: Node2D) -> void:
func _on_target_exited(body: Node2D) -> void:
func _select_target() -> void:
func _select_target_default() -> void:
	var unit_targets: Array[Node2D] = []
	var building_targets: Array[Node2D] = []
	var closest_target: Node2D = null
	var closest_distance: float = INF
	var search_list = unit_targets if not unit_targets.is_empty() else building_targets
		var dist_center = parent_node.global_position.distance_to(target.global_position)
		var radius = _get_target_radius(target)
		var distance = max(0, dist_center - radius)
func _select_target_defensive_siege() -> void:
	var unit_parent = parent_node as BaseUnit
	var great_hall = unit_parent.fsm.objective_target
		var hall_pos = great_hall.global_position
		var distance_to_hall = parent_node.global_position.distance_to(hall_pos)
	var closest_building: Node2D = null
	var closest_distance: float = INF
			var dist_center = parent_node.global_position.distance_to(target.global_position)
			var radius = _get_target_radius(target)
			var distance = max(0, dist_center - radius)
func _get_target_radius(target: Node2D) -> float:
		var building = target.get_parent() as BaseBuilding
			var size = min(building.data.grid_size.x, building.data.grid_size.y)
	var col = target.get_node_or_null("CollisionShape2D")
			var extents = col.shape.size / 2.0
func _start_attacking() -> void:
func _stop_attacking() -> void:
func _on_attack_timer_timeout() -> void:
	var limit = attack_range
	var dist = parent_node.global_position.distance_to(current_target.global_position)
	var r_target = _get_target_radius(current_target)
	var r_self = 15.0 
	var surface_dist = max(0, dist - r_target - r_self)
		var t = current_target
func _spawn_projectile(target_pos: Vector2) -> void:
	var p = ProjectilePoolManager.get_projectile()
```

### `res:///scenes/effects/Projectile.gd`
```gdscript
class_name Projectile
extends Area2D
var damage: int = 0
var speed: float = 400.0
var direction: Vector2 = Vector2.RIGHT
var firer: Node2D = null
@onready var lifetime_timer: Timer = $LifetimeTimer
func _ready() -> void:
func _physics_process(delta: float) -> void:
func setup(start_position: Vector2, target_position: Vector2, projectile_damage: int, projectile_speed: float = 400.0, collision_mask_value: int = 0) -> void:
func return_to_pool() -> void:
func _on_area_entered(area: Area2D) -> void:
func _on_body_entered(body: Node2D) -> void:
func _handle_impact(target: Node2D) -> void:
func _on_lifetime_timeout() -> void:
```

### `res:///scenes/levels/TempDebugNode.gd`
```gdscript
extends Node2D
const TILE_WIDTH = 64
const TILE_HEIGHT = 32
const TILE_HALF = Vector2(32, 16)
func _ready():
	var map = _find_tilemap()
	var test_cell = Vector2i(10, 10) 
	var map_center = map.to_global(map.map_to_local(test_cell))
	var manual_x = (test_cell.x - test_cell.y) * TILE_HALF.x
	var manual_y = (test_cell.x + test_cell.y) * TILE_HALF.y + TILE_HALF.y
	var manual_center = Vector2(manual_x, manual_y)
	var diff = map_center.distance_to(manual_center)
	var derived_cell = map.local_to_map(map.to_local(manual_center))
func _find_tilemap() -> TileMapLayer:
```

### `res:///scenes/missions/RaidMapLoader.gd`
```gdscript
class_name RaidMapLoader
extends Node
var building_container: Node2D
func setup(p_container: Node2D, enemy_data: SettlementData) -> void:
	var root_node = p_container.get_parent() 
	var tile_map = root_node.get_node_or_null("TileMapLayer")
func load_base(data: SettlementData, is_player_owner: bool) -> BaseBuilding:
	var objective_ref: BaseBuilding = null
		var building = _spawn_single_building_visual(entry)
func _spawn_single_building_visual(entry: Dictionary) -> BaseBuilding:
	var res_path = entry["resource_path"]
	var original_pos = Vector2i(entry["grid_position"].x, entry["grid_position"].y)
	var b_data = load(res_path) as BuildingData
	var final_grid_pos = original_pos
		var found_land = false
					var check = original_pos + Vector2i(x, y)
	var instance = b_data.scene_to_spawn.instantiate() as BaseBuilding
	var center_grid_x = float(final_grid_pos.x) + (float(b_data.grid_size.x) / 2.0)
	var center_grid_y = float(final_grid_pos.y) + (float(b_data.grid_size.y) / 2.0)
	var final_x = (center_grid_x - center_grid_y) * SettlementManager.TILE_HALF_SIZE.x
	var final_y = (center_grid_x + center_grid_y) * SettlementManager.TILE_HALF_SIZE.y
		var hitbox = instance.get_node("Hitbox")
```

### `res:///scenes/missions/RaidMission.gd`
```gdscript
extends Node2D
@export var enemy_wave_units: Array[UnitData] = []
@export var enemy_wave_count: int = 5
@export var enemy_base_data: SettlementData
@export var default_enemy_base_path: String = "res://data/settlements/monastery_base.tres"
@export var player_spawn_formation: Dictionary = {"units_per_row": 5, "spacing": 40}
@export var is_defensive_mission: bool = false
@export var enemy_spawn_position: NodePath
@export var landing_direction: Vector2 = Vector2.RIGHT
@onready var player_spawn_pos: Marker2D = $PlayerStartPosition
@onready var rts_controller: RTSController = $RTSController
@onready var building_container: Node2D = $BuildingContainer
@onready var objective_manager: RaidObjectiveManager = $RaidObjectiveManager
@onready var unit_spawner: UnitSpawner = $UnitSpawner
@export var fyrd_unit_scene: PackedScene
var map_loader: RaidMapLoader
var objective_building: BaseBuilding = null
var unit_container: Node2D
func _ready() -> void:
func _setup_unit_container() -> void:
func initialize_mission() -> void:
		var target_wrapper = RaidManager.current_raid_target
			var spawn_origin = Vector2(200, 300)
func _setup_defensive_mode() -> void:
	var settlement = SettlementManager.current_settlement
func _setup_offensive_mode() -> void:
func _on_building_destroyed_grid_update(building: BaseBuilding) -> void:
func _spawn_player_garrison() -> void:
	var warbands_to_spawn: Array[WarbandData] = []
	var spawn_origin = player_spawn_pos.global_position
func _spawn_enemy_wave() -> void:
	var spawner = get_node_or_null(enemy_spawn_position)
	var origin = spawner.global_position
		var random_data = enemy_wave_units.pick_random()
		var scene_ref = random_data.load_scene()
		var unit = scene_ref.instantiate()
		var offset = Vector2(i * 40, 0) # Basic formation
		var target_pos = origin + offset
func _on_fyrd_arrived() -> void:
		var fallback = "res://scenes/units/EnemyUnit_Template.tscn" 
	var spawner = get_node_or_null(enemy_spawn_position)
	var origin = spawner.global_position if spawner else Vector2(1000, 0)
		var unit = fyrd_unit_scene.instantiate()
		var random_offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
		var try_pos = origin + random_offset
		var valid_pos = SettlementManager.request_valid_spawn_point(try_pos, 3)
func _spawn_retreat_zone() -> void:
	var zone_script_path = "res://scenes/missions/RetreatZone.gd"
	var zone = Area2D.new()
	var poly = CollisionPolygon2D.new()
func _load_test_settlement() -> void:
	var data_path = "res://data/settlements/home_base_fixed.tres"
		var data = load(data_path)
func _on_settlement_ready_for_mission(_d):
func _validate_nodes() -> bool:
func _spawn_test_units() -> void:
	var unit_scene = load("res://scenes/units/PlayerVikingRaider.tscn")
		var u = unit_scene.instantiate()
		var offset = Vector2(i*30, 0)
		var pos = player_spawn_pos.global_position + offset
		var safe_pos = SettlementManager.request_valid_spawn_point(pos, 2)
func _spawn_enemy_garrison() -> void:
	var guard_buildings = []
func _on_node_added(node: Node) -> void:
func _on_civilian_surrender(civilian: Node2D) -> void:
	var best_leader = null
	var min_dist = INF
		var dist = leader.global_position.distance_to(civilian.global_position)
func command_scramble(target_position: Vector2) -> void:
	var controllable_units = get_tree().get_nodes_in_group("player_units")
		var panic_offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
		var unique_dest = target_position + panic_offset
```

### `res:///scenes/missions/RaidObjectiveManager.gd`
```gdscript
extends Node
class_name RaidObjectiveManager
@export var victory_bonus_loot: Dictionary = {"gold": 200}
@export var settlement_bridge_scene_path: String = "res://scenes/levels/SettlementBridge.tscn"
@export var is_defensive_mission: bool = false
var raid_loot: RaidLootData
var rts_controller: RTSController
var objective_building: BaseBuilding
var building_container: Node2D
var enemy_units: Array[BaseUnit] = [] 
var is_initialized: bool = false
var mission_over: bool = false
var battle_start_time: int = 0
var dead_units_log: Array[UnitData] = []
var escaped_unit_count: int = 0
const FYRD_ARRIVAL_TIME: float = 120.0 # 2 Minutes
var time_remaining: float = FYRD_ARRIVAL_TIME
var fyrd_timer_active: bool = false
var timer_label: Label
signal fyrd_arrived()
const UI_THEME = preload("res://ui/themes/VikingDynastyTheme.tres")
func _ready() -> void:
func _process(delta: float) -> void:
			var minutes = int(time_remaining / 60)
			var seconds = int(time_remaining) % 60
func initialize(
	var zones = get_tree().get_nodes_in_group("retreat_zone")
		var zone = zones[0]
func _on_player_unit_died(unit: Node2D) -> void:
		var ident = "A Warrior"
func _setup_mission_ui() -> void:
	var canvas = get_parent().get_node_or_null("CanvasLayer")
		var retreat_btn = Button.new()
func _setup_timer_ui() -> void:
	var canvas = get_parent().get_node_or_null("CanvasLayer")
func _on_retreat_ordered() -> void:
	var spawn_marker = get_parent().get_node_or_null("PlayerStartPosition")
func on_unit_evacuated(unit: BaseUnit) -> void:
	var remaining_units = get_tree().get_nodes_in_group("player_units")
	var living_count = 0
func _end_mission_via_retreat() -> void:
	var mission_result = RaidResultData.new()
func _connect_to_building_signals() -> void:
func _on_loot_stolen(type: String, amount: int) -> void:
func _on_enemy_building_destroyed_for_loot(building: BaseBuilding) -> void:
	var building_data = building.data as BuildingData
func _setup_win_loss_conditions() -> void:
func _check_loss_condition() -> void:
	var remaining_units = 0
func _check_defensive_win_condition() -> void:
func _on_player_hall_destroyed(_building: BaseBuilding) -> void:
func _on_defensive_mission_won() -> void:
func _on_mission_failed(reason: String) -> void:
		var report = DynastyManager.process_defensive_loss()
		var full_reason = reason + "\n\n" + report.get("summary_text", "")
func _on_enemy_hall_destroyed(_building: BaseBuilding = null) -> void:
	var duration_sec = (Time.get_ticks_msec() - battle_start_time) / 1000.0
	var grade = "Standard"
	var casualty_limit = 2
	var lost_count = dead_units_log.size()
	var mission_result = RaidResultData.new()
	var final_loot = raid_loot.collected_loot if raid_loot else {}
	var total_loot = final_loot.duplicate()
		var amount = victory_bonus_loot[key]
		var current = total_loot.get(key, 0)
	var difficulty = RaidManager.current_raid_difficulty
func _trigger_fyrd() -> void:
func _show_failure_message(reason: String) -> void:
	var popup = _create_popup_base()
	var label = Label.new()
func _show_victory_message(title: String, subtitle: String) -> void:
	var popup = _create_popup_base()
	var label = Label.new()
func _create_popup_base() -> Control:
	var popup = Control.new()
	var bg = Panel.new()
	var container = VBoxContainer.new()
func _add_popup_to_canvas(popup: Control) -> void:
	var canvas = get_parent().get_node_or_null("CanvasLayer")
func _on_raid_loot_secured(type: String, amount: int) -> void:
	var color = Color.GOLD if type == "gold" else Color.WHITE
```

### `res:///scenes/missions/RetreatZone.gd`
```gdscript
class_name RetreatZone
extends Area2D
signal unit_evacuated(unit: BaseUnit)
const COLOR_FILL = Color(0.2, 1.0, 0.2, 0.2) # Transparent Green
const COLOR_BORDER = Color(0.2, 1.0, 0.2, 0.8) # Solid Green Border
func _ready() -> void:
func _draw() -> void:
	var rect = Rect2(-100, -100, 200, 200)
	var font = ThemeDB.get_fallback_font()
func _on_body_entered(body: Node2D) -> void:
		var unit = body as BaseUnit
func _bank_unit_inventory(unit: BaseUnit) -> void:
	var total_value = 0
		var amount = unit.inventory[type]
func _evacuate_unit(unit: BaseUnit) -> void:
	var tween = create_tween()
```

### `res:///scenes/units/StuckDetector.gd`
```gdscript
extends Node
@export var parent_unit: CharacterBody2D
@export var check_interval: float = 0.5
@export var stuck_limit: int = 2
@export var unit_layer_index: int = 2 
var last_dist_to_target: float = 99999.0
var timer: float = 0.0
var stuck_count: int = 0
var is_phasing: bool = false
var cached_mask: int = 0 
func _ready() -> void:
func _physics_process(delta: float) -> void:
	var current_dist = 0.0
	var progress = last_dist_to_target - current_dist
func _set_phasing(active: bool) -> void:
func _is_trying_to_move() -> bool:
func _has_target() -> bool:
func _reset_stuck_status() -> void:
```

### `res:///scenes/units/UnitDebugger.gd`
```gdscript
extends Node2D
class_name UnitDebugger
@export var font_size: int = 12
@export var show_visuals: bool = true
var parent: CharacterBody2D
var stuck_detector: Node
var label: Label
func _ready() -> void:
func _process(_delta: float) -> void:
func _update_label() -> void:
	var mask_val = parent.collision_mask
	var vel_len = parent.velocity.length()
	var status = "OK"
	var txt = "ID: %s\n" % parent.name
	var slide_count = parent.get_slide_collision_count()
		var collider = parent.get_slide_collision(0).get_collider()
func _draw() -> void:
		var local_target = to_local(parent.formation_target)
func _unhandled_input(event: InputEvent) -> void:
		var mouse_pos = get_global_mouse_position()
func _print_deep_scan() -> void:
	var count = parent.get_slide_collision_count()
		var col = parent.get_slide_collision(i)
```

### `res:///scenes/world/ResourceNode.gd`
```gdscript
class_name ResourceNode
extends Area2D
signal node_depleted(node: ResourceNode)
@export_group("District Settings")
@export var resource_type: String = "wood":
@export var district_radius: float = 192.0:
@export_group("Pool Settings")
@export var max_pool: int = 1000
@export var current_pool: int = 1000
@export var is_infinite: bool = false
const DEBUG_COLORS = {
func _ready() -> void:
func _draw() -> void:
		var color = DEBUG_COLORS.get(resource_type, Color.WHITE)
func harvest(amount: int) -> int:
	var actual_amount = min(amount, current_pool)
func is_depleted() -> bool:
func is_position_in_district(world_pos: Vector2) -> bool:
func _on_depletion() -> void:
```

### `res:///scenes/world_map/MacroCamera.gd`
```gdscript
extends Camera2D 
class_name MacroCamera
@export_group("Movement")
@export var camera_speed: float = 500.0
@export var edge_pan_margin: float = 20.0
@export var enable_edge_panning: bool = true
@export var enable_keyboard_movement: bool = true
@export_group("Zoom")
@export var min_zoom: float = 0.5  # Far away
@export var max_zoom: float = 2.0  # Close up
@export var zoom_speed: float = 0.1
@export var zoom_smoothing: float = 10.0
@export_group("Bounds")
@export var bounds_enabled: bool = true 
@export var bounds_rect: Rect2 = Rect2(0, 0, 1920, 1080)
var target_zoom: Vector2 = Vector2.ONE
var is_dragging: bool = false
var drag_start_pos: Vector2
func _ready() -> void:
func snap_to_target(target_position: Vector2) -> void:
func _process(delta: float) -> void:
func _handle_movement(delta: float) -> void:
	var movement_vector := Vector2.ZERO
	var viewport_size = get_viewport().get_visible_rect().size
	var mouse_pos = get_viewport().get_mouse_position()
		var zoom_multiplier = 1.0 / zoom.x
func _unhandled_input(event: InputEvent) -> void:
func _zoom_in() -> void:
func _zoom_out() -> void:
func _clamp_zoom() -> void:
func _clamp_camera_to_bounds() -> void:
		var view_size = get_viewport_rect().size / zoom
		var min_x = bounds_rect.position.x + view_size.x / 2
		var max_x = bounds_rect.end.x - view_size.x / 2
		var min_y = bounds_rect.position.y + view_size.y / 2
		var max_y = bounds_rect.end.y - view_size.y / 2
```

### `res:///scenes/world_map/MacroMap.gd`
```gdscript
extends Node2D
@export var raid_mission_scene_path: String = "res://scenes/missions/RaidMission.tscn"
@export var settlement_bridge_scene_path: String = "res://scenes/levels/SettlementBridge.tscn"
@export var enemy_raid_chance: float = 0.25
@export var raid_prep_window_scene: PackedScene = preload("res://ui/RaidPrepWindow.tscn")
@export var player_home_marker_path: NodePath = "PlayerHomeMarker"
@onready var player_home_marker: Marker2D = get_node_or_null(player_home_marker_path)
@onready var macro_camera: MacroCamera = $MacroCamera
@onready var authority_label: Label = $UI/JarlInfo/VBoxContainer/AuthorityLabel
@onready var renown_label: Label = $UI/JarlInfo/VBoxContainer/RenownLabel
@onready var region_info_panel: PanelContainer = $UI/RegionInfo
@onready var region_name_label: Label = $UI/RegionInfo/VBoxContainer/RegionNameLabel
@onready var launch_raid_button: Button = $UI/RegionInfo/VBoxContainer/LaunchRaidButton 
@onready var target_list_container: VBoxContainer = $UI/RegionInfo/VBoxContainer/TargetList
@onready var settlement_button: Button = $UI/Actions/VBoxContainer/SettlementButton
@onready var subjugate_button: Button = $UI/RegionInfo/VBoxContainer/SubjugateButton
@onready var dynasty_button: Button = $UI/Actions/VBoxContainer/DynastyButton
@onready var dynasty_ui: DynastyUI = $UI/Dynasty_UI
@onready var marry_button: Button = $UI/RegionInfo/VBoxContainer/MarryButton
@onready var tooltip: PanelContainer = $UI/Tooltip
@onready var tooltip_label: Label = $UI/Tooltip/Label
@onready var regions_container: Node2D = $Regions
var raid_prep_window: RaidPrepWindow
var journey_report_dialog: AcceptDialog
const SAVE_PATH = "user://campaign_map.tres"
var map_state: MapState
var selected_region_data: WorldRegionData
var selected_region_node: Region = null
var calculated_subjugate_cost: int = 5 
var current_attrition_risk: float = 0.0
const SAFE_COLOR := Color(0.2, 0.8, 0.2, 0.1)   # Green
const RISK_COLOR := Color(1.0, 0.6, 0.0, 0.1)   # Orange
const HIGH_RISK_COLOR := Color(1.0, 0.0, 0.0, 0.1) # Red
func _ready() -> void:
func _initiate_raid(target: RaidTargetData) -> void:
func _finalize_raid_launch(target: RaidTargetData, warbands: Array[WarbandData], provision_level: int) -> void:
	var cost = target.raid_cost_authority
	var dist = 0.0
	var report = RaidManager.calculate_journey_attrition(dist)
func _transition_to_raid_scene() -> void:
func _draw() -> void:
	var jarl = DynastyManager.get_current_jarl()
	var safe_r = jarl.get_safe_range()
func _initialize_world_data() -> void:
func _generate_new_world() -> void:
	var jarl = DynastyManager.get_current_jarl()
	var safe_range = jarl.get_safe_range()
		var dist = player_home_marker.global_position.distance_to(region.get_global_center())
		var tier = 1
		var current_name = ""
		var data = MapDataGenerator.generate_region_data(tier, current_name)
func _apply_state_to_regions() -> void:
func _save_map_state() -> void:
	var error = ResourceSaver.save(map_state, SAVE_PATH)
func _on_region_selected(data: WorldRegionData) -> void:
	var jarl = DynastyManager.get_current_jarl()
		var dist = player_home_marker.global_position.distance_to(selected_region_node.get_global_center())
		var safe_range = jarl.get_safe_range()
			var overage = dist - safe_range
	var is_conquered = DynastyManager.has_conquered_region(data.resource_path)
	var is_allied = DynastyManager.is_allied_region(data.resource_path)
	var is_home = false
func _populate_raid_targets(data: WorldRegionData, is_conquered: bool, is_allied: bool, is_home: bool) -> void:
		var label = Label.new()
		var label = Label.new()
		var label = Label.new()
		var btn = Button.new()
		var risk_text = ""
		var btn_color = Color.WHITE
			var treasury = target.settlement_data.treasury
			var loot_type = "Mixed"
			var auth_cost = target.raid_cost_authority
			var can_afford = DynastyManager.can_spend_authority(auth_cost)
func _update_diplomacy_buttons(_data: WorldRegionData, is_conquered: bool, is_allied: bool, is_home: bool) -> void:
	var base_cost = 5
	var ally_mod = 0
	var has_heir = DynastyManager.get_available_heir_count() > 0
func _on_subjugate_pressed() -> void:
	var success = DynastyManager.spend_authority(calculated_subjugate_cost)
		var jarl = DynastyManager.get_current_jarl()
func _on_marry_pressed() -> void:
	var success = DynastyManager.marry_heir_for_alliance(selected_region_data.resource_path)
func _on_settlement_pressed() -> void: EventBus.scene_change_requested.emit(GameScenes.SETTLEMENT)
func _on_dynasty_pressed() -> void: if dynasty_ui: dynasty_ui.show()
func close_all_ui() -> void:
	var ui_closed = false
func _on_event_system_finished() -> void:
func _update_jarl_ui(jarl: JarlData) -> void:
func _update_region_status_visuals() -> void:
	var closest_dist = INF
	var home_region: Region = null
		var dist = player_home_marker.global_position.distance_to(region.get_global_center())
func _on_region_hovered(data: WorldRegionData, _screen_position: Vector2) -> void:
	var mouse_pos = get_viewport().get_mouse_position()
func _on_region_exited() -> void: tooltip.hide()
func _unhandled_input(event: InputEvent) -> void:
func _deselect_current_region() -> void:
```

### `res:///scenes/world_map/Region.gd`
```gdscript
class_name Region
extends Area2D
signal region_hovered(data: WorldRegionData, screen_position: Vector2)
signal region_exited()
signal region_selected(data: WorldRegionData)
@export var data: WorldRegionData
@onready var highlight_poly: Polygon2D = get_node_or_null("HighlightPoly")
@onready var collision_poly: CollisionPolygon2D = get_node_or_null("CollisionPolygon2D")
var default_color: Color = Color(0, 0, 0, 0)       # Invisible
var hover_color: Color = Color(1.0, 1.0, 1.0, 0.2) # Faint White
var selected_color: Color = Color(1.0, 0.9, 0.2, 0.4) # Yellowish
var home_color: Color = Color(0.2, 0.4, 0.8, 0.25) # Royal Blue (Owned)
var allied_hover_color: Color = Color(0.2, 0.8, 1.0, 0.3) # Cyan (Friendly)
var is_selected: bool = false
var is_home: bool = false   # Is this the player's starting region?
var is_allied: bool = false # Is this region allied via marriage?
func _ready() -> void:
func _sync_collision_shape() -> void:
func set_visual_state(is_hovered: bool) -> void:
	var target_color: Color
	var should_be_visible = true
	var tween = create_tween()
func _on_mouse_entered() -> void:
func _on_mouse_exited() -> void:
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
func get_global_center() -> Vector2:
	var sum = Vector2.ZERO
```

### `res:///scripts/ai/DefenderAI.gd`
```gdscript
class_name DefenderAI
extends AttackAI
@export var guard_radius: float = 300.0
@export var return_speed: float = 100.0
var guard_post: Vector2 = Vector2.ZERO
func _ready() -> void:
func _on_attack_timer_timeout() -> void:
	var dist_from_post = parent_node.global_position.distance_to(guard_post)
func _return_to_post() -> void:
func configure_guard_post(pos: Vector2) -> void:
```

### `res:///scripts/ai/SentryAI.gd`
```gdscript
extends Node2D
class_name SentryAI
@export var detection_radius: float = 80.0
@export var attack_damage: int = 25
@export var attack_cooldown: float = 1.5
var detection_area: Area2D
var attack_timer: float = 0.0
var current_target: Node2D = null
signal enemy_detected(target: Node2D)
signal attack_executed(target: Node2D, damage: int)
func _ready() -> void:
func _setup_detection_area() -> void:
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
func _process(delta: float) -> void:
func _on_body_entered(body: Node2D) -> void:
func _on_body_exited(body: Node2D) -> void:
func _attack_target(target: Node2D) -> void:
	var distance = global_position.distance_to(target.global_position)
func get_detection_radius() -> float:
func set_detection_radius(new_radius: float) -> void:
		var collision_shape = detection_area.get_child(0) as CollisionShape2D
func is_actively_defending() -> bool:
```

### `res:///scripts/ai/UnitAIConstants.gd`
```gdscript
class_name UnitAIConstants
extends RefCounted
enum State { 
enum Stance { 
static func get_surface_distance(unit_node: Node2D, target_node: Node2D) -> float:
	var dist_center = unit_node.global_position.distance_to(target_node.global_position)
	var r_target = _get_radius(target_node)
	var r_self = _get_radius(unit_node)
static func _get_radius(node: Node2D) -> float:
		var size = min(node.data.grid_size.x, node.data.grid_size.y)
		var b = node.get_parent()
		var size = min(b.data.grid_size.x, b.data.grid_size.y)
	var col = node.get_node_or_null("CollisionShape2D")
			var size = min(col.shape.size.x, col.shape.size.y)
```

### `res:///scripts/ai/UnitFSM.gd`
```gdscript
extends Node
class_name UnitFSM
var unit 
var attack_ai: AttackAI 
var current_state: UnitAIConstants.State = UnitAIConstants.State.IDLE
var stance: UnitAIConstants.Stance = UnitAIConstants.Stance.DEFENSIVE
var path: PackedVector2Array = []
var stuck_timer: float = 0.0
var los_range: float = 450.0
var target_position: Vector2 = Vector2.ZERO
var move_command_position: Vector2 = Vector2.ZERO
var objective_target: Node2D = null 
var current_target: Node2D = null 
var _pillage_accumulator: float = 0.0
func _init(p_unit, p_attack_ai: AttackAI) -> void:
func change_state(new_state: UnitAIConstants.State) -> void:
func _enter_state(state: UnitAIConstants.State) -> void:
func _exit_state(state: UnitAIConstants.State) -> void:
func _recalculate_path() -> void:
	var target_node = current_target if is_instance_valid(current_target) else objective_target
	var start_pos = unit.global_position
	var allow_partial = is_instance_valid(target_node)
func command_defensive_attack(attacker: Node2D) -> void:
func command_attack_obstruction(target: Node2D) -> void:
func command_collect(target: Node2D) -> void:
func command_move_to_formation_pos(target_pos: Vector2) -> void:
func command_move_to(target_pos: Vector2) -> void:
func command_attack(target: Node2D) -> void:
	var radius = _get_target_radius(target)
	var dist = unit.global_position.distance_to(target.global_position) - radius
func command_retreat(target_pos: Vector2) -> void:
func command_interact_move(target: Node2D) -> void:
func update(delta: float) -> void:
func _collect_state(delta: float) -> void:
	var work_range = 50.0 
	var dist = unit.global_position.distance_to(objective_target.global_position)
func _escort_state(delta: float) -> void:
func _regroup_state(delta: float) -> void:
func _idle_state(_delta: float) -> void:
func _formation_move_state(_delta: float) -> void:
	var next_waypoint: Vector2 = path[0]
	var direction: Vector2 = (next_waypoint - unit.global_position).normalized()
	var velocity: Vector2 = direction * unit.data.move_speed
func _move_state(delta: float) -> void:
	var next_waypoint: Vector2 = path[0]
	var direction: Vector2 = (next_waypoint - unit.global_position).normalized()
	var distance_to_waypoint = unit.global_position.distance_to(next_waypoint)
	var speed_mult = unit.get_speed_multiplier()
	var final_speed = unit.data.move_speed * speed_mult
func _interact_state(delta: float) -> void:
	var distance_to_target = UnitAIConstants.get_surface_distance(unit, objective_target)
	var interact_range = 25.0 # Close range for pillaging
			var next = path[0]
			var dir = (next - unit.global_position).normalized()
			var dir = (objective_target.global_position - unit.global_position).normalized()
func _process_pillage_tick(delta: float) -> void:
		var building = objective_target as BaseBuilding
		var amount_to_take = unit.data.pillage_speed
		var stolen_amount = building.steal_resources(amount_to_take)
func _retreat_state(delta: float) -> void:
		var next_waypoint: Vector2 = path[0]
		var direction: Vector2 = (next_waypoint - unit.global_position).normalized()
		var velocity: Vector2 = direction * unit.data.move_speed
	var dist_to_final = unit.global_position.distance_to(target_position)
		var direction = (target_position - unit.global_position).normalized()
func _attack_state(_delta: float) -> void:
	var radius = _get_target_radius(current_target)
	var dist = unit.global_position.distance_to(current_target.global_position) - radius
	var max_range = max(unit.data.attack_range, unit.data.building_attack_range)
func _resume_objective() -> void:
			var new_target = _find_closest_enemy_in_los()
func _find_closest_enemy_in_los() -> Node2D:
	var enemies = unit.get_tree().get_nodes_in_group("enemy_units")
	var closest: Node2D = null
	var min_dist = los_range
		var d = unit.global_position.distance_to(e.global_position)
func _on_ai_attack_started(target: Node2D) -> void:
func _on_ai_attack_stopped() -> void:
			var limit = unit.data.attack_range
			var radius = _get_target_radius(current_target)
			var dist = unit.global_position.distance_to(current_target.global_position) - radius
func _get_target_radius(target: Node2D) -> float:
		var b = target.get_parent() as BaseBuilding
			var size = min(b.data.grid_size.x, b.data.grid_size.y)
		var size = min(target.data.grid_size.x, target.data.grid_size.y)
	var col = target.get_node_or_null("CollisionShape2D")
func command_pillage(target: Node2D) -> void:
func _simple_move_to(target: Vector2, _delta: float) -> void:
	var dir = (target - unit.global_position).normalized()
	var speed_mult = unit.get_speed_multiplier() if unit.has_method("get_speed_multiplier") else 1.0
	var final_speed = unit.data.move_speed * speed_mult
```

### `res:///scripts/buildings/SettlementBridge.gd`
```gdscript
extends LevelBase
const MAP_WIDTH = 60
const MAP_HEIGHT = 60
@export var home_base_data: SettlementData
@export var test_building_data: BuildingData
@export var raider_scene: PackedScene
@export var end_of_year_popup_scene: PackedScene
@export var world_map_scene_path: String = "res://scenes/world_map/MacroMap.tscn"
@export_group("Loggie Debug Settings")
@export var show_ui_logs: bool = false:
@export var show_settlement_logs: bool = false:
@export var show_building_logs: bool = false:
@export var show_debug_logs: bool = true:
@export var show_raid_logs: bool = true:
@export_group("New Game Settings")
@export var start_gold: int = 1000
@export var start_wood: int = 500
@export var start_food: int = 100
@export var start_stone: int = 200
@export var start_population: int = 10
var default_test_building: BuildingData = preload("res://data/buildings/Bldg_Wall.tres")
var default_end_of_year_popup: PackedScene = preload("res://ui/EndOfYear_Popup.tscn")
@onready var unit_container: Node2D = $UnitContainer
@onready var ui_layer: CanvasLayer = $UI
@onready var storefront_ui: Control = $UI/Storefront_UI
@onready var building_cursor: Node2D = $BuildingCursor
@onready var building_container: Node2D = $BuildingContainer
@onready var rts_controller: RTSController = $RTSController
@onready var unit_spawner: UnitSpawner = $UnitSpawner
const WORK_ASSIGNMENT_SCENE_PATH = "res://ui/WorkAssignment_UI.tscn"
var work_assignment_ui: CanvasLayer
var end_of_year_popup: PanelContainer
var idle_warning_dialog: ConfirmationDialog
var great_hall_instance: BaseBuilding = null
var game_is_over: bool = false
var awaiting_placement: BuildingData = null
func _ready() -> void:
		var test_jarl = DynastyTestDataGenerator.generate_test_dynasty()
func _exit_tree() -> void:
func _connect_signals() -> void:
func _setup_default_resources() -> void:
func _setup_ui() -> void:
		var scene = load(WORK_ASSIGNMENT_SCENE_PATH)
func _on_worker_assignments_confirmed(assignments: Dictionary) -> void:
func _on_worker_requested(target: BaseBuilding) -> void:
	var index = SettlementManager.get_building_index(target)
	var is_construction = (target.current_state != BaseBuilding.BuildingState.ACTIVE)
	var entry
	var current_count = entry.get("peasant_count", 0)
	var incoming_count = target.get_meta("incoming_workers", 0)
	var total_allocated = current_count + incoming_count
	var capacity = 0
		var eco_data = target.data as EconomicBuildingData
	var civilians = get_tree().get_nodes_in_group("civilians")
	var nearest_civ: CivilianUnit = null
	var min_dist = INF
			var dist = civ.global_position.distance_to(target.global_position)
		var tween = create_tween()
		var walk_speed = 100.0
		var time = min_dist / walk_speed
		var civ_ref = weakref(nearest_civ)
			var current_inc = target.get_meta("incoming_workers", 1)
			var civ = civ_ref.get_ref()
func _finalize_worker_assignment(target: BaseBuilding, unit_node: Node2D) -> void:
	var index = SettlementManager.get_building_index(target)
		var is_construction = (target.current_state != BaseBuilding.BuildingState.ACTIVE)
		var entry
		var current = entry.get("peasant_count", 0)
		var cap = target.data.base_labor_capacity if is_construction else (target.data as EconomicBuildingData).peasant_capacity
func _on_worker_removal_requested(target: BaseBuilding) -> void:
	var index = SettlementManager.get_building_index(target)
	var entry
	var is_construction = (target.current_state != BaseBuilding.BuildingState.ACTIVE)
	var current_workers = entry.get("peasant_count", 0)
			var random_offset = Vector2(randf_range(-20, 20), randf_range(20, 40))
			var spawn_pos = target.global_position + random_offset
func _force_inspector_refresh(target: BaseBuilding) -> void:
	var inspector = ui_layer.get_node_or_null("BuildingInspector")
func _on_end_year_pressed() -> void:
	var idle_p = SettlementManager.get_idle_peasants()
	var idle_t = SettlementManager.get_idle_thralls()
	var total_idle = idle_p + idle_t
func _start_end_year_sequence() -> void:
func _on_payout_collected(payout: Dictionary) -> void:
		var amount = payout["renown"]
			var msg = "Renown %s %d (Loot Distribution)" % ["gained" if amount > 0 else "lost", abs(amount)]
func _close_all_popups() -> void:
	var dynasty_ui = ui_layer.get_node_or_null("Dynasty_UI")
func _clear_all_buildings() -> void:
func _initialize_settlement() -> void:
func _spawn_placed_buildings() -> void:
		var b = _spawn_single_building(building_entry, false) 
		var b = _spawn_single_building(building_entry, true)
			var progress = building_entry.get("progress", 0)
func _spawn_single_building(entry: Dictionary, is_new: bool) -> BaseBuilding:
	var res_path = entry["resource_path"]
	var grid_pos = Vector2i(entry["grid_position"].x, entry["grid_position"].y)
	var building_data = load(res_path) as BuildingData
	var new_building = building_data.scene_to_spawn.instantiate()
	var center_grid_x = float(grid_pos.x) + (float(building_data.grid_size.x) / 2.0)
	var center_grid_y = float(grid_pos.y) + (float(building_data.grid_size.y) / 2.0)
	var final_x = (center_grid_x - center_grid_y) * SettlementManager.TILE_HALF_SIZE.x
	var final_y = (center_grid_x + center_grid_y) * SettlementManager.TILE_HALF_SIZE.y
func _create_default_settlement() -> SettlementData:
	var settlement = SettlementData.new()
	var great_hall_entry = { "resource_path": "res://data/buildings/GreatHall.tres", "grid_position": Vector2i(28, 18) }
func _on_settlement_loaded(_settlement_data: SettlementData) -> void:
func _setup_great_hall(hall_instance: BaseBuilding) -> void:
func _on_great_hall_destroyed(_building: BaseBuilding) -> void:
func _on_building_ready_for_placement(building_data: BuildingData) -> void:
func _on_building_placement_cancelled(_building_data: BuildingData) -> void: pass
func _on_building_placement_completed() -> void:
		var grid_pos = SettlementManager.world_to_grid(building_cursor.global_position)
func _on_building_placement_cancelled_by_cursor() -> void:
func _on_building_right_clicked(building: BaseBuilding) -> void:
	var data = building.data
	var cost = data.build_cost
func _process_raid_return() -> void:
	var result: RaidResultData = RaidManager.pending_raid_result
	var outcome = result.outcome
	var raw_gold = result.loot.get("gold", 0)
	var total_wergild = 0
	var dead_count = 0
	var net_gold = max(0, raw_gold - total_wergild)
		var warbands_to_disband: Array[WarbandData] = []
	var grade = result.victory_grade
	var xp_gain = 0
	var loot_summary = result.loot.duplicate()
	var title_text = "Raid Result"
		var difficulty = RaidManager.current_raid_difficulty
		var bonus = 200 + (difficulty * 50)
		var jarl = DynastyManager.get_current_jarl()
		var total_loot_count = 0
		var popup = default_end_of_year_popup.instantiate()
func _sync_villagers(_data: SettlementData = null) -> void:
	var idle_count = SettlementManager.get_idle_peasants()
	var origin = great_hall_instance.global_position
func _toggle_dynasty_view() -> void:
	var dynasty_ui = ui_layer.get_node_or_null("Dynasty_UI")
func _spawn_player_garrison() -> void:
	var warbands = SettlementManager.current_settlement.warbands
	var origin = great_hall_instance.global_position
```

### `res:///scripts/data/GameResources.gd`
```gdscript
class_name GameResources
extends RefCounted
const GOLD := "gold"
const WOOD := "wood"
const FOOD := "food"
const STONE := "stone"
const POP_PEASANT := "peasant"
const POP_THRALL := "thrall"
const ALL_CURRENCIES = [GOLD, WOOD, FOOD, STONE]
const ALL_POPULATION = [POP_PEASANT, POP_THRALL]
static func get_display_name(key: String) -> String:
```

### `res:///scripts/data/GameScenes.gd`
```gdscript
class_name GameScenes
extends RefCounted
const SETTLEMENT := "settlement"
const WORLD_MAP := "world_map"
const RAID_MISSION := "raid_mission"
const WINTER_COURT := "winter_court"
```

### `res:///scripts/formations/SquadFormation.gd`
```gdscript
class_name SquadFormation
extends RefCounted # Changed from implicit to explicit for better memory management
enum FormationType {
var formation_type: FormationType = FormationType.LINE
var unit_spacing: float = 40.0
var max_units_per_row: int = 4
var units: Array[Node2D] = []
var leader_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var formation_center: Vector2 = Vector2.ZERO
var is_moving: bool = false
var move_speed: float = 100.0
func _init(squad_units: Array[Node2D] = []) -> void:
func add_unit(unit: Node2D) -> void:
func remove_unit(unit: Node2D) -> void:
func set_formation_type(new_type: FormationType) -> void:
func move_to_position(target_pos: Vector2, direction: Vector2 = Vector2.DOWN) -> void:
	var formation_positions = _calculate_formation_positions(target_pos, direction)
	var claimed_cells: Array[Vector2i] = []
		var unit = units[i]
		var raw_dest = formation_positions[i]
		var final_dest = raw_dest
			var grid_spot = SettlementManager.world_to_grid(final_dest)
func _calculate_formation_positions(center_pos: Vector2, direction: Vector2) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var unit_count = units.size()
	var rotation_angle = Vector2.DOWN.angle_to(direction * -1.0)
	var rotated_positions: Array[Vector2] = []
		var relative_pos = pos - center_pos
		var rotated_relative_pos = relative_pos.rotated(rotation_angle)
func _calculate_line_formation(center_pos: Vector2, unit_count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var start_x = center_pos.x - (unit_count - 1) * unit_spacing * 0.5
func _calculate_column_formation(center_pos: Vector2, unit_count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var start_y = center_pos.y - (unit_count - 1) * unit_spacing * 0.5
func _calculate_wedge_formation(center_pos: Vector2, unit_count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var side_offset = unit_spacing * 0.7 
	var rear_offset = unit_spacing
		var row = (i + 1) / 2 
		var side = 1 if i % 2 == 1 else -1 
		var pos = Vector2(
func _calculate_box_formation(center_pos: Vector2, unit_count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var rows = int(ceil(float(unit_count) / max_units_per_row))
	var cols = min(unit_count, max_units_per_row)
	var start_x = center_pos.x - (cols - 1) * unit_spacing * 0.5
	var start_y = center_pos.y - (rows - 1) * unit_spacing * 0.5
		var row = i / max_units_per_row
		var col = i % max_units_per_row
		var row_unit_count = min(max_units_per_row, unit_count - row * max_units_per_row)
		var row_start_x = center_pos.x - (row_unit_count - 1) * unit_spacing * 0.5
		var pos = Vector2(
func _calculate_circle_formation(center_pos: Vector2, unit_count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var radius = max(unit_spacing, unit_count * unit_spacing / (2 * PI))
		var angle = (2 * PI * i) / unit_count
func _move_unit_to_position(unit: Node2D, target_pos: Vector2) -> void:
func _update_formation_positions() -> void:
func _calculate_center_position() -> Vector2:
	var total_pos = Vector2.ZERO
func get_unit_count() -> int: return units.size()
func is_squad_moving() -> bool: return is_moving
func get_formation_info() -> Dictionary:
```

### `res:///scripts/generators/DynastyGenerator.gd`
```gdscript
class_name DynastyGenerator
extends RefCounted
const MALE_NAMES = ["Ragnar", "Bjorn", "Ivar", "Sigurd", "Ubbe", "Halfdan", "Harald", "Erik", "Leif", "Sven", "Olaf", "Knut", "Torstein", "Floki", "Rollo", "Arvid"]
const FEMALE_NAMES = ["Lagertha", "Aslaug", "Gunnhild", "Torvi", "Helga", "Siggy", "Astrid", "Freydis", "Ylva", "Thyra", "Ingrid", "Ragnhild", "Sif", "Hilda"]
const SURNAMES = ["Lothbrok", "Ironside", "the Boneless", "Snake-in-the-Eye", "Fairhair", "Red", "the Lucky", "Forkbeard"]
const PORTRAIT_PATHS = {
static func generate_random_dynasty() -> JarlData:
	var jarl = JarlData.new()
	var heir_count = randi_range(1, 2)
		var heir = _generate_heir(jarl.age)
static func _generate_heir(parent_age: int) -> JarlHeirData:
	var heir = JarlHeirData.new()
	var max_age = max(0, parent_age - 16)
static func _generate_name(gender: String, include_surname: bool = true) -> String:
	var name_list = MALE_NAMES if gender == "Male" else FEMALE_NAMES
	var first = name_list.pick_random()
		var last = SURNAMES.pick_random()
static func _get_random_portrait(gender: String, age: int) -> Texture2D:
	var age_category = "Adult"
		var paths = PORTRAIT_PATHS[gender][age_category]
			var path = paths.pick_random()
static func generate_newborn() -> JarlHeirData:
	var baby = JarlHeirData.new()
		var trait_data = JarlTraitData.new()
static func get_random_viking_name() -> String:
	var gender = "Male" if randf() > 0.2 else "Female" # Mostly male raiders historically
	var list = MALE_NAMES if gender == "Male" else FEMALE_NAMES
```

### `res:///scripts/generators/MapDataGenerator.gd`
```gdscript
class_name MapDataGenerator
extends RefCounted
const REGION_NAMES = [
const LAYOUT_MONASTERY = "res://data/settlements/monastery_base.tres"
const LAYOUT_VILLAGE = "res://data/settlements/economic_base.tres"
const LAYOUT_FORTRESS = "res://data/settlements/fortress_layout.tres"
const B_FARM = "res://data/buildings/generated/Eco_Farm.tres"
const B_MARKET = "res://data/buildings/generated/Eco_Market.tres"
const B_RELIC = "res://data/buildings/generated/Eco_Reliquary.tres"
const B_HALL = "res://data/buildings/GreatHall.tres"
const B_WALL = "res://data/buildings/Bldg_Wall.tres"
static func generate_region_data(tier: int, fixed_name: String = "") -> WorldRegionData:
	var data = WorldRegionData.new()
	var base_diff = 1.0 + (float(tier - 1) * 0.8)
	var variance = randf_range(0.0, 0.5)
	var final_difficulty = base_diff + variance
	var target_count = randi_range(1, 3)
	var min_cost = 999 
		var target = _generate_target_for_tier(data.display_name, tier, final_difficulty)
static func _generate_name() -> String:
static func _generate_target_for_tier(region_name: String, tier: int, difficulty: float) -> RaidTargetData:
	var target = RaidTargetData.new()
	var type = _pick_type_by_tier(tier)
static func _pick_type_by_tier(tier: int) -> String:
	var roll = randf()
static func _generate_procedural_settlement(type: String, difficulty: float) -> SettlementData:
	var s = SettlementData.new()
	var occupied_grid = {}
	var map_center = Vector2i(30, 20)
	var hall_path = B_HALL
	var building_count = int(3 * difficulty)
	var primary_path = B_FARM
		var path = primary_path
			var radius = randi_range(4, 12) # Keep within 4-12 tiles of center (Safe Land)
			var angle = randf() * TAU
			var offset = Vector2(cos(angle), sin(angle)) * radius
			var target_pos = map_center + Vector2i(round(offset.x), round(offset.y))
static func _try_place_building(settlement: SettlementData, occupied: Dictionary, res_path: String, pos: Vector2i) -> bool:
	var b_data = load(res_path) as BuildingData
	var width = b_data.grid_size.x
	var height = b_data.grid_size.y
	var buffer = 1 
			var check_pos = pos + Vector2i(x, y)
			var mark_pos = pos + Vector2i(x, y)
static func _clone_settlement_data(original: SettlementData) -> SettlementData:
	var clone = SettlementData.new()
static func _scale_garrison(settlement: SettlementData, multiplier: float) -> void:
		var possible_paths = [
		var unit_data: UnitData = null
			var count = int(3 * multiplier)
				var wb = WarbandData.new(unit_data)
	var original_count = settlement.warbands.size()
	var target_count = int(original_count * multiplier)
	var needed = target_count - original_count
			var source = settlement.warbands.pick_random()
			var new_wb = WarbandData.new(source.unit_type)
```

### `res:///scripts/generators/TerrainGenerator.gd`
```gdscript
class_name TerrainGenerator
extends RefCounted
const TERRAIN_SET_ID = 0 
const TERRAIN_BEACH = 0
const TERRAIN_SHALLOW = 1
const TERRAIN_DEEP = 2
const TERRAIN_GRASS = 3
const LEVEL_BEACH_START = 50   # Land goes much further down now
const LEVEL_SHALLOW_START = 55
const LEVEL_DEEP_START = 58
static func generate_base_terrain(tile_layer: TileMapLayer, width: int, height: int, map_seed: int) -> void:
	var rng = RandomNumberGenerator.new()
	var terrain_map = {}
			var grid_pos = Vector2i(x, y)
			var noise = rng.randi_range(-1, 1)
			var effective_y = y + noise
	var cells_grass: Array[Vector2i] = []
	var cells_beach: Array[Vector2i] = []
	var cells_shallow: Array[Vector2i] = []
	var cells_deep: Array[Vector2i] = []
		var type = terrain_map[pos]
static func _carve_fjord(terrain_map: Dictionary, width: int, height: int, rng: RandomNumberGenerator) -> void:
	var current_x = rng.randi_range(20, 40) # Middle of map
	var current_y = height + 2 # Start off-screen at bottom
	var end_y = rng.randi_range(10, 20)
		var progress = float(current_y) / float(height) # 0.0 (top) to 1.0 (bottom)
		var fjord_width = int(lerp(2.0, 8.0, progress)) # 2 tiles wide at tip, 8 at mouth
				var pos = Vector2i(x, y)
static func _add_coastline_around(terrain_map: Dictionary, water_pos: Vector2i) -> void:
	var neighbors = [
		var check_pos = water_pos + n
```

### `res:///scripts/ui/BuildingPreviewCursor.gd`
```gdscript
extends Node2D
class_name BuildingPreviewCursor
const ISO_PLACEHOLDER_SCRIPT = "res://scripts/utility/IsoPlaceholder.gd"
var current_building_data: BuildingData
var preview_visuals: Node2D 
var is_active: bool = false
var error_label: Label 
var grid_overlay: Node2D
var can_place: bool = false
var current_grid_pos: Vector2i = Vector2i.ZERO
var valid_color: Color = Color(0.4, 1.0, 0.4, 0.7)    # Greenish
var invalid_color: Color = Color(1.0, 0.4, 0.4, 0.7)  # Reddish
var nearest_node: Node2D = null 
var tether_color_valid: Color = Color(0.2, 1.0, 0.2, 0.8) 
var tether_color_invalid: Color = Color(1.0, 0.2, 0.2, 0.8)
signal placement_completed
signal placement_cancelled
func _ready() -> void:
func set_building_preview(building_data: BuildingData) -> void:
	var tex_to_use: Texture2D = null
		var sprite = Sprite2D.new()
func _create_procedural_placeholder(data: BuildingData) -> Node2D:
	var placeholder = Node2D.new()
		var script = load(ISO_PLACEHOLDER_SCRIPT)
func _extract_texture_from_scene(packed_scene: PackedScene) -> Texture2D:
	var instance = packed_scene.instantiate()
	var found_tex: Texture2D = null
func _process(_delta: float) -> void:
	var mouse_pos = get_global_mouse_position()
		var error = SettlementManager.get_placement_error(current_grid_pos, current_building_data.grid_size, current_building_data)
func _input(event: InputEvent) -> void:
func _try_place_building() -> void:
func cancel_preview() -> void:
func _cleanup_preview() -> void:
func _update_visual_feedback() -> void:
func _find_nearest_resource_node(world_pos: Vector2) -> void:
	var target_type = (current_building_data as EconomicBuildingData).resource_type
	var min_dist = INF
	var nodes = get_tree().get_nodes_in_group("resource_nodes")
			var dist = world_pos.distance_to(node.global_position)
func _draw() -> void:
		var start = Vector2.ZERO 
		var end = to_local(nearest_node.global_position)
		var dist = global_position.distance_to(nearest_node.global_position)
		var radius = 300.0
		var is_in_range = dist <= radius
		var color = tether_color_valid if is_in_range else tether_color_invalid
func _create_grid_outline(grid_size: Vector2i) -> void:
	var tile_size = Vector2(64, 32)
	var half_w = tile_size.x * 0.5 # 32
	var half_h = tile_size.y * 0.5 # 16
	var basis_x = Vector2(half_w, half_h)
	var basis_y = Vector2(-half_w, half_h)
	var w = float(grid_size.x)
	var h = float(grid_size.y)
	var top_left_grid = Vector2(-w * 0.5, -h * 0.5)
	var p_top_left = (basis_x * top_left_grid.x) + (basis_y * top_left_grid.y)
	var p_top_right = (basis_x * (top_left_grid.x + w)) + (basis_y * top_left_grid.y)
	var p_bot_right = (basis_x * (top_left_grid.x + w)) + (basis_y * (top_left_grid.y + h))
	var p_bot_left = (basis_x * top_left_grid.x) + (basis_y * (top_left_grid.y + h))
	var rect = Line2D.new()
func _clear_grid_overlay() -> void:
```

### `res:///scripts/ui/PauseMenu.gd`
```gdscript
extends CanvasLayer
@onready var main_container: VBoxContainer = $PanelContainer/MainMenuContainer
@onready var resume_button: Button = $PanelContainer/MainMenuContainer/ResumeButton
@onready var save_button: Button = $PanelContainer/MainMenuContainer/SaveButton
@onready var debug_button: Button = $PanelContainer/MainMenuContainer/DebugButton
@onready var new_game_button: Button = $PanelContainer/MainMenuContainer/NewGameButton
@onready var quit_button: Button = $PanelContainer/MainMenuContainer/QuitButton
@onready var debug_container: VBoxContainer = $PanelContainer/DebugMenuContainer
@onready var btn_add_gold: Button = $PanelContainer/DebugMenuContainer/Btn_AddGold
@onready var btn_add_renown: Button = $PanelContainer/DebugMenuContainer/Btn_AddRenown
@onready var btn_unlock_legacy: Button = $PanelContainer/DebugMenuContainer/Btn_UnlockLegacy
@onready var btn_trigger_raid: Button = $PanelContainer/DebugMenuContainer/Btn_TriggerRaid
@onready var btn_kill_jarl: Button = $PanelContainer/DebugMenuContainer/Btn_KillJarl
@onready var btn_back: Button = $PanelContainer/DebugMenuContainer/Btn_Back
func _ready() -> void:
	var container = find_child("VBoxContainer", true, false) # Adjust if your layout is named differently
		var debug_raid_btn = Button.new()
func _unhandled_input(event: InputEvent) -> void:
func _on_debug_raid_pressed() -> void:
	var debug_target = RaidTargetData.new()
	var base_path = "res://data/settlements/monastery_base.tres"
	var army: Array[WarbandData] = []
		var unit_data = load("res://data/units/Unit_PlayerRaider.tres") # Check path!
			var wb = WarbandData.new(unit_data)
func _on_resume_pressed() -> void:
func _on_debug_menu_pressed() -> void:
func _on_back_pressed() -> void:
func _on_save_pressed() -> void:
func _on_new_game_pressed() -> void:
func _on_quit_pressed() -> void:
func _cheat_add_gold() -> void:
func _cheat_add_renown() -> void:
func _cheat_unlock_legacy() -> void:
func _cheat_trigger_raid() -> void:
	var debug_target = RaidTargetData.new()
	var base_path = "res://data/settlements/monastery_base.tres"
		var unit_data = load("res://data/units/Unit_PlayerRaider.tres")
			var wb = WarbandData.new(unit_data)
func _cheat_kill_jarl() -> void:
```

### `res:///scripts/ui/WinterCourt_UI.gd`
```gdscript
class_name WinterCourtUI
extends Control
@onready var action_label: Label = $MarginContainer/ScreenMargin/RootLayout/TopLayout/LeftPanel/VBoxContainer/ActionPointsLabel
@onready var jarl_name_label: Label = $MarginContainer/ScreenMargin/RootLayout/TopLayout/LeftPanel/VBoxContainer/JarlNameLabel
@onready var jarl_portrait: TextureRect = $MarginContainer/ScreenMargin/RootLayout/TopLayout/LeftPanel/VBoxContainer/JarlPortrait
@onready var upkeep_label: RichTextLabel = $MarginContainer/ScreenMargin/RootLayout/TopLayout/RightPanel/VBoxContainer/UpkeepLabel
@onready var fleet_label: Label = $MarginContainer/ScreenMargin/RootLayout/TopLayout/RightPanel/VBoxContainer/FleetLabel
@onready var unrest_label: Label = $MarginContainer/ScreenMargin/RootLayout/TopLayout/RightPanel/VBoxContainer/UnrestLabel
@onready var btn_thing: Button = $MarginContainer/ScreenMargin/RootLayout/TopLayout/CenterPanel/Btn_Thing
@onready var btn_refit: Button = $MarginContainer/ScreenMargin/RootLayout/TopLayout/CenterPanel/Btn_Refit
@onready var btn_feast: Button = $MarginContainer/ScreenMargin/RootLayout/TopLayout/CenterPanel/Btn_Feast
@onready var btn_end_winter: Button = $MarginContainer/ScreenMargin/RootLayout/BottomPanel/Btn_EndWinter
@onready var btn_blot: Button = $MarginContainer/ScreenMargin/RootLayout/TopLayout/CenterPanel/Btn_Blot
@onready var dispute_overlay: PanelContainer = $DisputeOverlay
@onready var dispute_title: RichTextLabel = $DisputeOverlay/MarginContainer/VBoxContainer/TitleLabel
@onready var dispute_desc: RichTextLabel = $DisputeOverlay/MarginContainer/VBoxContainer/DescriptionLabel
@onready var btn_resolve_1: Button = $DisputeOverlay/MarginContainer/VBoxContainer/HBoxContainer/Btn_Gold
@onready var btn_resolve_2: Button = $DisputeOverlay/MarginContainer/VBoxContainer/HBoxContainer/Btn_Force
@onready var btn_resolve_3: Button = $DisputeOverlay/MarginContainer/VBoxContainer/HBoxContainer/Btn_Ignore
var current_dispute: DisputeEventData = null
var winter_start_acknowledged: bool = false
func _ready() -> void:
func _update_ui() -> void:
	var jarl = DynastyManager.current_jarl
	var settlement = SettlementManager.current_settlement
	var readiness_pct := int(settlement.fleet_readiness * 100)
func _show_winter_start_popup() -> void:
	var report = WinterManager.winter_consumption_report
	var severity = report.get("severity_name", "NORMAL")
	var flavor = ""
	var color_tag = "white"
	var desc = "[center][color=%s][b]%s WINTER[/b][/color][/center]\n\n" % [color_tag, severity]
func _show_crisis_state() -> void:
	var report = WinterManager.winter_consumption_report
	var text = "[center][color=red][b]CRISIS: SHORTAGES[/b][/color][/center]\n"
func _show_normal_state() -> void:
	var report = WinterManager.winter_upkeep_report
	var text = "[b]Winter Log:[/b]\n"
func _update_button_states() -> void:
	var has_actions := DynastyManager.current_jarl.current_hall_actions > 0
	var settlement = SettlementManager.current_settlement
	var warband_count = settlement.warbands.size()
	var food_cost = max(100, warband_count * 50)
	var current_food = settlement.treasury.get("food", 0)
	var can_afford_feast = current_food >= food_cost
	var feast_tt = "COST: %d Food, 1 Hall Action\nEFFECT: +50 Renown, Maximize Loyalty." % food_cost
	var gather_tt = "COST: 1 Hall Action\nEFFECT: Attract Seasonal Drengir."
func _disconnect_overlay_buttons() -> void:
	var buttons = [btn_resolve_1, btn_resolve_2, btn_resolve_3]
func _display_crisis_overlay() -> void:
	var report = WinterManager.winter_consumption_report
	var food_def = report["food_deficit"]
	var wood_def = report["wood_deficit"]
	var food_total = report.get("food_cost", 0)
	var wood_total = report.get("wood_cost", 0)
	var narrative_title = "HARDSHIP"
	var narrative_body = ""
	var text = "[center]%s[/center]\n\n" % narrative_body
	var missing_items = []
	var gold_cost = (food_def * 5) + (wood_def * 5)
	var has_action = DynastyManager.current_jarl.current_hall_actions > 0
		var deaths = max(1, int(food_def / 5))
func _on_end_winter_pressed() -> void:
func _on_gather_warband_clicked() -> void:
	var jarl = DynastyManager.get_current_jarl()
	var total_squads_arrived = 1 + randi_range(0, 2) + int(jarl.renown / 100.0)
	var ship_cap = SettlementManager.get_total_ship_capacity_squads()
	var current_squads = SettlementManager.current_settlement.warbands.size()
	var open_slots = max(0, ship_cap - current_squads)
	var accepted = min(total_squads_arrived, open_slots)
	var rejected = total_squads_arrived - accepted
		var drengr = load("res://data/units/Unit_Drengr.tres")
	var result_text = "[color=green]Recruited: %d Squads[/color]" % accepted
		var renown_loss = rejected * 10
func _on_thing_clicked() -> void:
		var card = EventManager.draw_dispute_card()
func _display_dispute(card: DisputeEventData) -> void:
func _on_dispute_pay_gold() -> void:
func _on_dispute_pay_force() -> void:
		var s = SettlementManager.current_settlement
func _on_dispute_ignore() -> void:
func _on_feast_clicked() -> void:
	var s = SettlementManager.current_settlement
	var cost = max(100, s.warbands.size() * 50)
func _on_blot_clicked() -> void:
func _display_blot_options() -> void:
func _commit_blot(key: String, god: String) -> void:
func _display_action_result(title: String, flavor: String, result: String) -> void:
func _close_overlay() -> void:
```

### `res:///scripts/units/Base_Unit.gd`
```gdscript
class_name BaseUnit
extends CharacterBody2D
signal destroyed
signal fsm_ready(unit)
@export var data: UnitData
var unit_identity: String = ""
var warband_ref: WarbandData
var fsm
var current_health: int = 50
var attack_ai: AttackAI = null
var _last_pos: Vector2 = Vector2.ZERO
var _stuck_timer: float = 0.0
@onready var attack_timer: Timer = $AttackTimer
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var separation_area: Area2D = $SeparationArea
@export_group("AI")
@export var separation_enabled: bool = true
@export var separation_force: float = 30.0
@export var separation_radius: float = 40.0
@export var avoidance_enabled: bool = true
@export var avoidance_force: float = 150.0 
@export var whisker_length: float = 40.0
@export var avoidance_priority: int = 1
@export var debug_avoidance_logs: bool = true
var _debug_log_timer: float = 0.0
var uses_external_steering: bool = false
var _last_avoid_dir: Vector2 = Vector2.ZERO
var _color_tween: Tween
const STATE_COLORS := {
const ERROR_COLOR := Color(0.7, 0.3, 1.0)
const LAYER_ENV = 1
const LAYER_PLAYER_UNIT = 2
const LAYER_ENEMY_UNIT = 4
const LAYER_ENEMY_BLDG = 8
var _is_dying: bool = false
signal inventory_updated(current_load: int, max_load: int)
var inventory: Dictionary = {} 
var current_loot_weight: int = 0
func _ready() -> void:
	var hp_mult = 1.0
	var dmg_mult = 1.0
		var level_mult = warband_ref.get_stat_multiplier()
			var heir = DynastyManager.find_heir_by_name(warband_ref.assigned_heir_name)
					var p_bonus = 1.0 + ((heir.prowess - 5) * 0.10)
	var area_shape = separation_area.get_node_or_null("CollisionShape2D")
func _setup_collision_logic() -> void:
	var physics_mask = 0
	var separation_mask = 0
	var is_player = (collision_layer & LAYER_PLAYER_UNIT) != 0
	var is_enemy = (collision_layer & LAYER_ENEMY_UNIT) != 0
func _deferred_setup(damage_mult: float = 1.0) -> void:
			var target_mask = 0
func _apply_texture_and_scale() -> void:
	var target_size: Vector2 = data.target_pixel_size
		var texture_size: Vector2 = sprite.texture.get_size()
func _exit_tree() -> void:
func _on_grid_updated(_grid_pos: Vector2i) -> void:
func _physics_process(delta: float) -> void:
	var desired_velocity = Vector2.ZERO
	var final_velocity = desired_velocity
func calculate_separation_push(delta: float) -> Vector2:
	var push_vector = Vector2.ZERO
	var neighbors = separation_area.get_overlapping_bodies()
			var away_vector = global_position - neighbor.global_position
			var distance_sq = away_vector.length_squared()
				var current_push_strength = 1.0 - (sqrt(distance_sq) / separation_radius)
func _calculate_obstacle_avoidance() -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var speed_ratio = velocity.length() / max(data.move_speed, 1.0)
	var current_whisker_len = whisker_length * clamp(speed_ratio, 0.2, 1.2)
	var angles = [0.0, deg_to_rad(-35), deg_to_rad(35)]
	var hit_count = 0
	var total_escape_dir = Vector2.ZERO
	var log_hits = []
		var dir = velocity.normalized().rotated(angle)
		var query = PhysicsRayQueryParameters2D.create(
		var result = space_state.intersect_ray(query)
			var hit_normal = result.normal
			var tangent_left = Vector2(-hit_normal.y, hit_normal.x)
			var tangent_right = Vector2(hit_normal.y, -hit_normal.x)
			var dot_left = tangent_left.dot(velocity)
			var dot_right = tangent_right.dot(velocity)
			var best_tangent = tangent_left
			var normal_influence = 0.05 # Default: Only 5% pushback, 95% slide
			var escape_dir = (best_tangent * (1.0 - normal_influence)) + (hit_normal * normal_influence)
	var final_steer = Vector2.ZERO
		var avg_dir = total_escape_dir / hit_count
func _check_stuck_timer(delta: float) -> void:
	var distance_moved = global_position.distance_squared_to(_last_pos)
func _handle_stuck_unit() -> void:
		var random_nudge = Vector2(randf_range(-1,1), randf_range(-1,1)) * 10.0
func on_state_changed(state: UnitAIConstants.State) -> void:
	var to_color: Color = STATE_COLORS.get(state, Color.WHITE)
func flash_error_color() -> void:
	var back_color: Color = STATE_COLORS.get(fsm.current_state, Color.WHITE)
	var t := create_tween()
func _tween_color(to_color: Color, duration: float = 0.2) -> void:
func take_damage(amount: int, attacker: Node2D = null) -> void:
func die() -> void:
func command_move_to(target_pos: Vector2) -> void:
func command_attack(target: Node2D) -> void:
var is_selected: bool = false
func set_selected(selected: bool) -> void:
func _draw() -> void:
func _create_unit_hitbox() -> void:
	var hitbox_area = Area2D.new()
	var layer_value = LAYER_PLAYER_UNIT
	var hitbox_shape = CollisionShape2D.new()
func command_retreat(target_pos: Vector2) -> void:
func command_start_working(target_building: BaseBuilding, target_node: ResourceNode) -> void:
func add_loot(resource_type: String, amount: int) -> int:
	var cap = data.max_loot_capacity if "max_loot_capacity" in data else 0
	var space_left = cap - current_loot_weight
	var actual_amount = min(amount, space_left)
func get_speed_multiplier() -> float:
	var cap = data.max_loot_capacity if "max_loot_capacity" in data else 0
	var penalty = data.encumbrance_speed_penalty if "encumbrance_speed_penalty" in data else 0.0
	var ratio = float(current_loot_weight) / float(cap)
```

### `res:///scripts/units/CivilianUnit.gd`
```gdscript
class_name CivilianUnit
extends BaseUnit
@export_group("Mob AI")
@export var mob_separation_force: float = 100.0 
@export var mob_separation_radius: float = 45.0 
@export var thrall_unit_scene: PackedScene 
@export var surrender_hp_threshold: int = 10 # Triggers when HP <= 10
signal surrender_requested(civilian_node: Node2D)
var interaction_target: BaseBuilding = null
var skip_assignment_logic: bool = false
var _is_surrendered: bool = false
var escort_target: Node2D = null
func _ready() -> void:
func _physics_process(delta: float) -> void:
func take_damage(amount: int, attacker: Node2D = null) -> void:
func _trigger_surrender() -> void:
func attach_to_escort(soldier: Node2D) -> void:
func _process_surrender_behavior(_delta: float) -> void:
		var dist = global_position.distance_to(escort_target.global_position)
			var dir = (escort_target.global_position - global_position).normalized()
func command_interact(target: Node2D) -> void:
```

### `res:///scripts/units/EnemyVikingRaider.gd`
```gdscript
extends BaseUnit
func set_attack_target(target: BaseBuilding) -> void:
```

### `res:///scripts/units/PlayerVikingRaider.gd`
```gdscript
extends BaseUnit
class_name PlayerVikingRaider
func _ready() -> void:
func command_attack(target: Node2D) -> void:
func die() -> void:
```

### `res:///scripts/units/SquadLeader.gd`
```gdscript
class_name SquadLeader
extends BaseUnit
var squad_soldiers: Array[SquadSoldier] = []
var formation: SquadFormation
var last_facing_direction: Vector2 = Vector2.DOWN
var attached_thralls: Array[ThrallUnit] = []
var debug_formation_points: Array[Vector2] = []
func _ready() -> void:
func _initialize_squad() -> void:
func _recruit_fresh_squad() -> void:
	var soldiers_needed = max(0, warband_ref.current_manpower - 1)
	var base_scene = data.load_scene()
		var soldier_instance = base_scene.instantiate()
		var soldier_script = load("res://scripts/units/SquadSoldier.gd")
func attach_thrall(thrall: ThrallUnit) -> void:
		var angle = randf_range(PI/4, 3*PI/4) # Behind (90 to 270 degrees roughly)
		var dist = randf_range(40.0, 80.0)
func _physics_process(delta: float) -> void:
	var is_voluntarily_moving = false
func _update_formation_targets(snap_to_position: bool = false) -> void:
	var slots = formation._calculate_formation_positions(global_position, last_facing_direction)
		var soldier = squad_soldiers[i]
			var target = slots[i+1]
func _draw() -> void:
			var point = to_local(debug_formation_points[i])
func remove_soldier(soldier: SquadSoldier) -> void:
func absorb_existing_soldiers(list: Array[SquadSoldier]) -> void:
func _refresh_formation_registry() -> void:
func set_selected(val: bool) -> void:
func die() -> void:
	var living_soldiers: Array[SquadSoldier] = []
		var new_leader_host = living_soldiers.pop_front()
		var new_leader = duplicate()
func on_state_changed(new_state: int) -> void:
func _order_squad_attack() -> void:
	var target = fsm.current_target
func _order_squad_regroup() -> void:
func request_escort_for(civilian: Node2D) -> void:
	var best_candidate: SquadSoldier = null
	var min_dist = INF
	var max_batch_dist = 300.0
	var max_prisoners = 3
			var total_load = soldier.escorted_prisoners.size() + soldier.pending_prisoners.size()
				var dist = soldier.global_position.distance_to(civilian.global_position)
		var closest_combatant = null
		var closest_d = INF
			var state = soldier.fsm.current_state
				var dist = soldier.global_position.distance_to(civilian.global_position)
```

### `res:///scripts/units/SquadSoldier.gd`
```gdscript
class_name SquadSoldier
extends BaseUnit
var leader: SquadLeader
var formation_target: Vector2 = Vector2.ZERO
var brawl_target: Node2D = null
var is_rubber_banding: bool = false
var stuck_detector: Node
const MAX_DIST_FROM_LEADER = 300.0
const CATCHUP_DIST = 80.0
const SPRINT_SPEED_MULT = 2.5
var pending_prisoners: Array[Node2D] = [] 
var escorted_prisoners: Array[Node2D] = []
var retreat_zone_cache: Node2D = null
func _ready() -> void:
func _physics_process(delta: float) -> void:
	var speed = data.move_speed
	var dist_leader = global_position.distance_to(leader.global_position)
	var is_phasing = false
	var final_dest = formation_target
	var stop_dist = 15.0
		var range_limit = data.attack_range
		var r_target = _get_radius(brawl_target)
		var dist = global_position.distance_to(final_dest)
			var desired_velocity = (final_dest - global_position).normalized() * speed
func _get_radius(node: Node2D) -> float:
		var b = node.get_parent()
func assign_escort_task(prisoner: Node2D) -> void:
func _set_next_collection_target() -> void:
		var next = pending_prisoners[0]
func process_collecting_logic(_delta: float) -> void:
	var dist = global_position.distance_to(fsm.objective_target.global_position)
func _collect_prisoner(prisoner: Node2D) -> void:
func _switch_to_escorting() -> void:
func process_escort_logic(_delta: float) -> void:
func complete_escort() -> void:
	var count = 0
func process_regroup_logic(_delta: float) -> void:
```

### `res:///scripts/units/ThrallUnit.gd`
```gdscript
class_name ThrallUnit
extends BaseUnit
var assigned_leader: Node2D = null
var follow_offset: Vector2 = Vector2.ZERO
func _ready() -> void:
func _physics_process(delta: float) -> void:
func _process_baggage_movement(delta: float) -> void:
	var target_pos = assigned_leader.global_position + follow_offset
	var dist = global_position.distance_to(target_pos)
		var dir = (target_pos - global_position).normalized()
		var move_speed = data.move_speed
```

### `res:///scripts/utility/GridUtils.gd`
```gdscript
class_name GridUtils
extends RefCounted
const TILE_WIDTH: int = 64
const TILE_HEIGHT: int = 32
const TILE_SIZE := Vector2(TILE_WIDTH, TILE_HEIGHT)
const TILE_HALF := Vector2(TILE_WIDTH * 0.5, TILE_HEIGHT * 0.5)
static func grid_to_iso(grid_pos: Vector2i) -> Vector2:
	var x = (grid_pos.x - grid_pos.y) * TILE_HALF.x
	var y = (grid_pos.x + grid_pos.y) * TILE_HALF.y
static func iso_to_grid(world_pos: Vector2) -> Vector2i:
	var x = (world_pos.x / TILE_HALF.x + world_pos.y / TILE_HALF.y) * 0.5
	var y = (world_pos.y / TILE_HALF.y - world_pos.x / TILE_HALF.x) * 0.5
static func snap_to_grid(world_pos: Vector2) -> Vector2:
	var grid_pos = iso_to_grid(world_pos)
static func get_center_offset(grid_size: Vector2i) -> Vector2:
	var offset_x = (grid_size.x - 1.0 - (grid_size.y - 1.0)) * TILE_HALF.x * 0.5
	var offset_y = (grid_size.x - 1.0 + (grid_size.y - 1.0)) * TILE_HALF.y * 0.5
static func is_within_bounds(grid: AStarGrid2D, cell: Vector2i) -> bool:
static func is_area_clear(grid: AStarGrid2D, top_left_pos: Vector2i, size: Vector2i) -> bool:
			var cell = top_left_pos + Vector2i(x, y)
static func calculate_territory(placed_buildings: Array, grid_region: Rect2i) -> Dictionary:
	var buildable_map: Dictionary = {}
		var path = entry.get("resource_path", "")
		var data = load(path) as BuildingData
			var raw_pos = entry["grid_position"]
			var center = Vector2i(raw_pos.x, raw_pos.y)
			var r = data.territory_radius
			var r_sq = r * r
					var cell = Vector2i(x, y)
```

### `res:///scripts/utility/GridVisualizer.gd`
```gdscript
class_name GridVisualizer
extends Node2D
@export_group("Grid Settings")
@export var show_grid: bool = true:
@export var debug_show_solids: bool = false: # DISABLED BY DEFAULT
@export var grid_size: Vector2i = Vector2i(60, 40):
@export var tile_dimensions: Vector2i = Vector2i(64, 32):
@export_tool_button("Force Redraw") var force_redraw_action = _on_force_redraw
const GRID_COLOR := Color(1.0, 1.0, 1.0, 0.1) 
const BORDER_COLOR := Color(1.0, 0.6, 0.0, 0.8) 
const SOLID_COLOR := Color(1.0, 0.0, 0.0, 0.3)
var _iso_offsets: PackedVector2Array = []
func _ready() -> void:
			var path_drawer = load("res://scripts/utility/UnitPathDrawer.gd").new() 
func _on_force_redraw() -> void:
func _precalculate_iso_offsets() -> void:
	var half = Vector2(tile_dimensions) * 0.5
func _draw() -> void:
	var cam = get_viewport().get_camera_2d()
		var center = NavigationManager._world_to_grid(cam.get_screen_center_position())
		var range_val = 20 
		var grid = NavigationManager.active_astar_grid
		var region = grid.region
				var cell = Vector2i(x, y)
func _draw_iso_poly_optimized(grid_pos: Vector2i, color: Color, fill: bool) -> void:
	var center = NavigationManager._grid_to_world(grid_pos)
	var points = _iso_offsets.duplicate()
func _draw_map_border() -> void:
func _draw_optimized_grid() -> void:
	var col = GRID_COLOR
	var half_w = tile_dimensions.x * 0.5
	var half_h = tile_dimensions.y * 0.5
	var grid_to_iso = func(g: Vector2i) -> Vector2:
		var start = grid_to_iso.call(Vector2i(x, 0))
		var end = grid_to_iso.call(Vector2i(x, grid_size.y))
		var start = grid_to_iso.call(Vector2i(0, y))
		var end = grid_to_iso.call(Vector2i(grid_size.x, y))
```

### `res:///scripts/utility/IsoPlaceholder.gd`
```gdscript
class_name IsoPlaceholder
extends Node2D
@export var data: BuildingData:
@export var color: Color = Color.CORNFLOWER_BLUE:
@export var height: float = 64.0:
const TILE_WIDTH = 64
const TILE_HEIGHT = 32
func _ready() -> void:
func _draw() -> void:
func _draw_iso_box(size: Vector2i, base_color: Color) -> void:
	var half_w = TILE_WIDTH * 0.5
	var half_h = TILE_HEIGHT * 0.5
	var total_w = (size.x + size.y) * half_w
	var total_h = (size.x + size.y) * half_h
	var p_top = Vector2(0, -total_h * 0.5) 
	var p_right = Vector2(total_w * 0.5, 0)
	var p_bottom = Vector2(0, total_h * 0.5)
	var p_left = Vector2(-total_w * 0.5, 0)
	var vec_x = Vector2(half_w, half_h) # Down-Right
	var vec_y = Vector2(-half_w, half_h) # Down-Left
	var top_origin = -((vec_x * size.x) + (vec_y * size.y)) * 0.5
	var c_top = top_origin
	var c_right = top_origin + (vec_x * size.x)
	var c_bottom = top_origin + (vec_x * size.x) + (vec_y * size.y)
	var c_left = top_origin + (vec_y * size.y)
	var roof_offset = Vector2(0, -height)
	var r_top = c_top + roof_offset
	var r_right = c_right + roof_offset
	var r_bottom = c_bottom + roof_offset
	var r_left = c_left + roof_offset
	var wall_left_pts = PackedVector2Array([c_left, c_bottom, r_bottom, r_left])
	var wall_right_pts = PackedVector2Array([c_bottom, c_right, r_right, r_bottom])
	var roof_pts = PackedVector2Array([r_left, r_bottom, r_right, r_top])
	var base_pts = PackedVector2Array([c_top, c_right, c_bottom, c_left, c_top])
```

### `res:///scripts/utility/LevelBase.gd`
```gdscript
class_name LevelBase
extends Node2D
func setup_level_navigation(tilemap_layer: TileMapLayer, width: int, height: int) -> void:
```

### `res:///scripts/utility/RTSInputHandler.gd`
```gdscript
class_name RTSInputHandler
extends Node
var input_enabled: bool = true
func _ready() -> void:
func _unhandled_input(event: InputEvent) -> void:
func _handle_control_groups(event: InputEventKey) -> void:
		var group_index = event.keycode - KEY_0
func _handle_formations(event: InputEventKey) -> void:
```

### `res:///scripts/utility/UnitPathDrawer.gd`
```gdscript
class_name UnitPathDrawer
extends Node2D
var _cached_units: Array[Node] = []
var _cache_timer: float = 0.0
func _ready() -> void:
func _process(delta: float) -> void:
func _refresh_unit_cache() -> void:
func _draw() -> void:
				var points = PackedVector2Array([unit.global_position])
```

### `res:///scripts/utility/UnitSpawner.gd`
```gdscript
class_name UnitSpawner
extends Node
@export_group("References")
@export var unit_container: Node2D
@export var rts_controller: RTSController
@export_group("Defaults")
@export var civilian_data: UnitData
@export var spawn_radius_min: float = 100.0
@export var spawn_radius_max: float = 250.0
const LAYER_PLAYER = 2
const LAYER_ENEMY = 4
const SQUAD_SPACING = 150.0
const UNITS_PER_ROW = 5
func _ready() -> void:
func clear_units() -> void:
func spawn_garrison(warbands: Array[WarbandData], spawn_origin: Vector2) -> void:
	var current_index = 0
		var ideal_pos = _calculate_formation_pos(spawn_origin, current_index)
		var unit_instance = _spawn_unit_core(warband, ideal_pos, true)
func spawn_enemy_garrison(warbands: Array[WarbandData], buildings: Array) -> void:
		var warband = warbands[i]
		var guard_pos = Vector2.ZERO
			var b = buildings[i % buildings.size()]
		var unit_instance = _spawn_unit_core(warband, guard_pos, false)
func _spawn_unit_core(warband: WarbandData, target_pos: Vector2, is_player: bool) -> BaseUnit:
	var unit_data = warband.unit_type
	var scene_ref = unit_data.load_scene()
	var final_pos = target_pos
	var unit = scene_ref.instantiate() as BaseUnit
		var leader_script = load("res://scripts/units/SquadLeader.gd")
func _calculate_formation_pos(origin: Vector2, index: int) -> Vector2:
	var row = index / UNITS_PER_ROW
	var col = index % UNITS_PER_ROW
	var offset = Vector2(
func _validate_spawn_setup() -> bool:
func _on_enemy_unit_ready(unit: BaseUnit, guard_pos: Vector2) -> void:
func sync_civilians(target_count: int, spawn_origin: Vector2, is_enemy: bool = false) -> void:
	var current_civs = []
	var diff = target_count - current_civs.size()
func _spawn_civilians(count: int, origin: Vector2, is_enemy: bool) -> void:
	var scene_ref = civilian_data.load_scene()
		var civ = scene_ref.instantiate()
		var angle = randf() * TAU
		var distance = randf_range(spawn_radius_min, spawn_radius_max)
		var tentative_pos = origin + (Vector2(cos(angle), sin(angle)) * distance)
		var final_pos = tentative_pos
			var grid_check = NavigationManager._world_to_grid(tentative_pos)
			var is_water = NavigationManager.is_point_solid(grid_check)
				var safe_pos = NavigationManager.request_valid_spawn_point(tentative_pos, 5)
func _despawn_civilians(count: int, list: Array) -> void:
			var civ = list[i]
func spawn_worker_at(location: Vector2) -> void:
	var scene_ref = civilian_data.load_scene()
	var civ = scene_ref.instantiate()
```

### `res:///test/base/GutTestBase.gd`
```gdscript
class_name GutTestBase
extends GutTest
func before_each():
func create_mock_jarl(authority: int = 3, renown: int = 100) -> JarlData:
	var jarl = JarlData.new()
func create_mock_settlement(pop: int = 10, food: int = 100) -> SettlementData:
	var s = SettlementData.new()
func create_mock_warband(unit_data: UnitData = null) -> WarbandData:
	var wb = WarbandData.new(unit_data)
```

### `res:///test/fixtures/DynastyTestDataGenerator.gd`
```gdscript
class_name DynastyTestDataGenerator
extends RefCounted
static func generate_test_dynasty() -> JarlData:
	var jarl = JarlData.new()
	var ancestors_data: Array[Dictionary] = [
	var heir1 = JarlHeirData.new()
	var heir2 = JarlHeirData.new()
	var heir3 = JarlHeirData.new()
	var heir4 = JarlHeirData.new()
```

### `res:///test/fixtures/SmokeTest.gd`
```gdscript
extends Node2D
const UNIT_SPAWNER_SCRIPT = preload("res://scripts/utility/UnitSpawner.gd")
const PLAYER_UNIT_DATA_PATH = "res://data/units/Unit_PlayerRaider.tres"
var spawner: UnitSpawner
var unit_container: Node2D
var rts_controller: RTSController
func _ready() -> void:
	var warbands = _create_mock_warbands()
func _setup_scene_tree() -> void:
func _create_mock_warbands() -> Array[WarbandData]:
	var list: Array[WarbandData] = []
	var u_data = load(PLAYER_UNIT_DATA_PATH)
	var wb = WarbandData.new()
func _verify_spawn_results() -> void:
	var leaders = []
	var leader = leaders[0]
	var minions = []
```

### `res:///test/fixtures/TestUtils.gd`
```gdscript
class_name TestUtils
extends RefCounted
static func create_dummy_data() -> UnitData:
	var d = UnitData.new()
static func create_mock_unit(unit_class, parent_node: Node, data_override: UnitData = null) -> Node2D:
	var unit = unit_class.new()
	var sprite = Sprite2D.new()
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var col = CollisionShape2D.new()
	var timer = Timer.new()
	var sep = Area2D.new()
	var sep_col = CollisionShape2D.new()
static func create_mock_end_year_popup() -> PanelContainer:
	var root = PanelContainer.new()
	var margin = MarginContainer.new()
	var vbox = VBoxContainer.new()
	var label = RichTextLabel.new()
	var loot_panel = PanelContainer.new()
	var slider = HSlider.new()
	var dist_label = Label.new()
	var btn = Button.new()
	var script = load("res://ui/EndOfYear_Popup.gd")
static func create_mock_bridge() -> Node:
	var bridge_script = load("res://scripts/buildings/SettlementBridge.gd")
	var bridge = bridge_script.new()
	var unit_cont = Node2D.new()
	var ui_node = CanvasLayer.new()
```

### `res:///test/integration/test_building_placement.gd`
```gdscript
extends GutTest
	func _ready():
	func set_state(_val): 
var _manager_ref
var _container
func before_all():
func test_building_visual_alignment():
	var mock_data = BuildingData.new()
	var mock_node = MockBuilding.new()
	var dummy_scene = PackedScene.new()
	var target_grid = Vector2i(5, 5)
	var building_instance = _manager_ref.place_building(mock_data, target_grid)
	var actual_pos = building_instance.global_position
	var expected_x = 0.0
	var expected_y = 176.0 
func after_all():
```

### `res:///test/integration/test_economy_flow.gd`
```gdscript
extends GutTestBase
func test_population_growth_with_surplus():
	var s = create_mock_settlement(10, 500) # 10 Pop, 500 Food (Abundance)
	var payout = EconomyManager.calculate_payout()
	var growth_str = payout.get("population_growth", "")
func test_construction_labor_deduction():
	var s = create_mock_settlement(10, 100)
	var blueprint = {
	var updated_bp = s.pending_construction_buildings[0]
```

### `res:///test/integration/test_escort_cycle.gd`
```gdscript
extends GutTestBase
var leader: SquadLeader
var soldier: SquadSoldier
var civilian: CivilianUnit
var retreat_zone: Area2D
func before_each():
func test_civilian_surrender_signal():
func test_leader_finds_volunteer():
func test_soldier_collects_prisoner():
func test_escort_completion():
func test_batching_logic():
	var civ1 = TestUtils.create_mock_unit(CivilianUnit, self)
	var civ2 = TestUtils.create_mock_unit(CivilianUnit, self)
```

### `res:///test/integration/test_fleet_mechanics.gd`
```gdscript
extends GutTestBase
const NAUST_PATH = "res://data/buildings/generated/Bldg_Naust.tres"
func before_each():
func test_base_fleet_capacity():
	var cap = SettlementManager.get_total_ship_capacity_squads()
func test_naust_increases_capacity():
	var entry = {
	var cap = SettlementManager.get_total_ship_capacity_squads()
func test_overflow_logic():
	var s = SettlementManager.current_settlement
	var arriving_squads = 5
	var capacity = SettlementManager.get_total_ship_capacity_squads() # Should be 3
	var current_filled = s.warbands.size() # 3
	var open_slots = max(0, capacity - current_filled)
	var accepted = min(arriving_squads, open_slots)
	var rejected = arriving_squads - accepted
func test_naust_solves_overflow():
	var s = SettlementManager.current_settlement
	var capacity = SettlementManager.get_total_ship_capacity_squads() # Should be 6 now
	var arriving_squads = 2
	var current_filled = s.warbands.size() # 3
	var open_slots = max(0, capacity - current_filled) # 6 - 3 = 3 slots
	var accepted = min(arriving_squads, open_slots)
	var rejected = arriving_squads - accepted
```

### `res:///test/integration/test_military_spawning.gd`
```gdscript
extends GutTestBase
var spawner: UnitSpawner
var unit_container: Node2D
var rts_controller: RTSController
const RAIDER_DATA_PATH = "res://data/units/Unit_PlayerRaider.tres"
func before_each():
func test_spawn_full_strength_squad():
	var unit_data = load(RAIDER_DATA_PATH)
	var warband = create_mock_warband(unit_data)
	var child_count = unit_container.get_child_count()
	var leaders = get_nodes_by_class(unit_container, "SquadLeader")
		var leader = leaders[0] as SquadLeader
	var minions = get_nodes_by_class(unit_container, "SquadSoldier")
func test_wounded_warband_skipped():
	var unit_data = load(RAIDER_DATA_PATH)
	var warband = create_mock_warband(unit_data)
func test_multiple_squad_offset():
	var unit_data = load(RAIDER_DATA_PATH)
	var wb1 = create_mock_warband(unit_data)
	var wb2 = create_mock_warband(unit_data)
	var leaders = get_nodes_by_class(unit_container, "SquadLeader")
		var l1 = leaders[0]
		var l2 = leaders[1]
		var dist = l1.global_position.distance_to(Vector2(1000, 1000))
func get_nodes_by_class(parent: Node, class_name_str: String) -> Array:
	var result = []
```

### `res:///test/integration/test_navigation_logic.gd`
```gdscript
extends GutTest
var _grid: AStarGrid2D
var _nav_manager = NavigationManager 
func before_each():
func after_each():
func test_smoothing_removes_zigzag():
	var start_pos = Vector2(16, 16) 
	var end_pos = Vector2(336, 336) 
	var path = _nav_manager.get_astar_path(start_pos, end_pos)
	var last_point = path[path.size() - 1]
func test_start_position_precision_fix():
	var exact_unit_pos = Vector2(5, 5)
	var target_pos = Vector2(100, 100)
	var path = _nav_manager.get_astar_path(exact_unit_pos, target_pos)
func test_obstacle_avoidance_with_smoothing():
	var start_pos = Vector2(16, 16)   # 0,0
	var end_pos = Vector2(80, 80)     # 2,2
	var path = _nav_manager.get_astar_path(start_pos, end_pos)
	var wall_center = Vector2(48, 48) # Center of 1,1
		var dist = point.distance_to(wall_center)
func test_out_of_bounds_handling():
	var start = Vector2(16, 16)
	var waaaay_out = Vector2(99999, 99999)
	var path = _nav_manager.get_astar_path(start, waaaay_out)
	var last_point = path[path.size() - 1]
```

### `res:///test/integration/test_new_game_flow.gd`
```gdscript
extends GutTest
const USER_SAVE_PATH = "user://savegame_dynasty.tres"
func before_each():
func after_all():
func test_generator_produces_valid_jarl():
	var jarl = DynastyGenerator.generate_random_dynasty()
	var designated_found = false
func test_heir_age_logic():
	var jarl = DynastyGenerator.generate_random_dynasty()
		var max_possible_age = jarl.age - 16
func test_start_new_campaign_flow():
	var current = DynastyManager.current_jarl
func test_persistence_loading():
	var original_name = DynastyManager.current_jarl.display_name
	var loaded_jarl = DynastyManager.get_current_jarl()
```

### `res:///test/integration/test_terrain_solids.gd`
```gdscript
extends GutTest
var _manager_ref
var _layer: TileMapLayer
var _container: Node2D
var _scene_root: Node2D
func before_all():
	var ts = TileSet.new()
	var source = TileSetAtlasSource.new()
	var tex = PlaceholderTexture2D.new()
	var tile_data = source.get_tile_data(Vector2i(0, 0), 0)
	var source_id = ts.add_source(source)
func test_water_blocks_grid():
	var is_solid = _manager_ref.active_astar_grid.is_point_solid(Vector2i(5, 5))
		var data = _layer.get_cell_tile_data(Vector2i(5, 5))
		var val = data.get_custom_data("is_unwalkable") if data else "NULL DATA"
	var is_empty_solid = _manager_ref.active_astar_grid.is_point_solid(Vector2i(6, 6))
func after_all():
```

### `res:///test/integration/test_winter_systems.gd`
```gdscript
extends GutTest
func before_each():
	var jarl = JarlData.new()
func after_all():
func test_winter_crisis_detection_starvation():
	var settlement = SettlementData.new()
	var report = DynastyManager.winter_consumption_report
func test_winter_crisis_resolution_via_gold():
	var settlement = SettlementData.new()
	var success = DynastyManager.resolve_crisis_with_gold()
func test_ui_locking_during_crisis():
	var settlement = SettlementData.new()
	var ui = autoqfree(load("res://ui/WinterCourt_UI.tscn").instantiate())
	var btn_end = ui.find_child("Btn_EndWinter", true, false)
```

### `res:///test/test_year_cycle.gd`
```gdscript
extends Node
func _ready():
func test_starvation():
	var settlement = SettlementData.new()
	var jarl = JarlData.new()
	var payout = EconomyManager.calculate_payout()
func test_overpopulation():
	var settlement = SettlementData.new()
	var jarl = JarlData.new()
	var payout = EconomyManager.calculate_payout()
func test_draft_and_raid_solution():
	var settlement = SettlementData.new()
	var jarl = JarlData.new()
	var bondi_data
	var raid_loot = {
	var payout = EconomyManager.calculate_payout()
```

### `res:///test/unit/test_RaidManager.gd`
```gdscript
extends GutTest
var raid_manager
var mock_jarl
func before_each():
func after_each():
func test_initial_state():
func test_prepare_raid_force():
	var warband = WarbandData.new()
	var force: Array[WarbandData] = [warband]
func test_attrition_safe_range():
	var result = raid_manager.calculate_journey_attrition(10.0)
func test_attrition_risky_range():
	var result = raid_manager.calculate_journey_attrition(5000.0)
func test_defensive_loss_renoun():
	var result = raid_manager.process_defensive_loss()
```

### `res:///test/unit/test_WinterManager.gd.gd`
```gdscript
extends GutTest
var winter_manager
var mock_settlement
var mock_jarl
func before_each():
func after_each():
func test_calculate_demand_normal():
	var report = winter_manager.calculate_winter_demand(mock_settlement)
func test_consumption_applied_when_affordable():
func test_crisis_trigger():
func test_resolve_crisis_with_gold():
	var success = winter_manager.resolve_crisis_with_gold()
func test_resolve_sacrifice_burn_ships():
	var success = winter_manager.resolve_crisis_with_sacrifice("burn_ships")
```

### `res:///test/unit/test_economy_seasonal.gd`
```gdscript
extends GutTest
const TEMP_BUILDING_PATH = "user://temp_test_eco_building.tres"
var _mock_settlement: SettlementData
var _mock_jarl: JarlData
func before_all():
	var b_data = EconomicBuildingData.new()
func after_all():
func before_each():
func after_each():
func test_projected_income_calculation():
	var projection = EconomyManager.get_projected_income()
func test_seasonal_payout_spring():
func test_seasonal_payout_autumn_food():
	var farm_data = EconomicBuildingData.new()
	var farm_path = "user://temp_test_farm.tres"
func test_storage_caps():
func test_stewardship_bonus():
	var projection = EconomyManager.get_projected_income()
func _add_building_to_settlement(path: String):
```

### `res:///test/unit/test_grid_math.gd`
```gdscript
extends GutTestBase
func test_origin_alignment():
	var result = GridUtils.grid_to_iso(Vector2i(0, 0))
func test_step_check():
	var result = GridUtils.grid_to_iso(Vector2i(1, 0))
func test_round_trip():
	var start_grid = Vector2i(5, 7)
	var world_pos = GridUtils.grid_to_iso(start_grid)
	var end_grid = GridUtils.iso_to_grid(world_pos)
func test_snap_to_grid():
	var input = Vector2(33, 17)
	var snapped = GridUtils.snap_to_grid(input)
func test_bounds_check():
	var grid = AStarGrid2D.new()
```

### `res:///test/unit/test_inventory_mechanics.gd`
```gdscript
extends GutTestBase
var unit: BaseUnit
var unit_data: UnitData
func before_each():
func after_each():
func test_add_loot_under_cap():
	var added = unit.add_loot("gold", 50)
func test_add_loot_over_cap():
	var added = unit.add_loot("gold", 50) # Try adding 50 more (only 20 space left)
func test_encumbrance_math():
```

### `res:///test/unit/test_spawn_logic.gd`
```gdscript
extends GutTest
var _manager_ref
var _grid_width = 10
var _grid_height = 10
func before_all():
func test_spawn_safety_check():
	var water_pos = _manager_ref.grid_to_world(Vector2i(0, 0))
	var result = _manager_ref.request_valid_spawn_point(water_pos, 2) # Check radius 2
	var shore_water_pos = _manager_ref.grid_to_world(Vector2i(5, 4))
	var shore_result = _manager_ref.request_valid_spawn_point(shore_water_pos, 2)
	var result_grid = _manager_ref.world_to_grid(shore_result)
func test_spawn_on_valid_land():
	var land_pos = _manager_ref.grid_to_world(Vector2i(5, 5))
	var result = _manager_ref.request_valid_spawn_point(land_pos, 2)
```

### `res:///test/unit/test_squad_math.gd`
```gdscript
extends GutTestBase
var formation: SquadFormation
func before_each():
func test_line_formation_positions():
	var center = Vector2(100, 100)
	var facing = Vector2.DOWN
	var count = 3
	var points = formation._calculate_formation_positions(center, facing)
func test_box_formation_rotation():
	var center = Vector2.ZERO
	var facing = Vector2.RIGHT 
	var points = formation._calculate_formation_positions(center, facing)
	var p2 = points[1]
```

### `res:///test/unit/test_wergild.gd`
```gdscript
extends GutTestBase
var bridge_instance = null
var bondi_data = null
var drengr_data = null
var popup_instance = null
func before_each():
func test_wergild_calculation_simple():
	var result = {
	var total_wergild = 0
	var net_gold = result.gold_looted - total_wergild
func test_wergild_bankruptcy_protection():
	var result = {
	var total_wergild = result.casualties[0].wergild_cost
	var net_gold = max(0, result.gold_looted - total_wergild)
```

### `res:///test/unit/test_winter_math.gd`
```gdscript
extends GutTest
var _default_harsh: float
var _default_mild: float
func before_all():
func after_each():
func test_demand_calculation_normal():
	var settlement = SettlementData.new()
	var report = WinterManager.calculate_winter_demand(settlement)
func test_demand_calculation_harsh():
	var settlement = SettlementData.new()
	var report = WinterManager.calculate_winter_demand(settlement)
```

### `res:///tools/AIContentImporter.gd`
```gdscript
extends EditorScript
const BASE_DIR_UNITS = "res://data/units/"
const BASE_DIR_BUILDINGS = "res://data/buildings/"
var RAW_DATA = [
func _run():
	var count = 0
		var res: Resource
		var base_path = ""
		var sub_folder = entry.get("sub_folder", "generated") # Default to 'generated' if missing
			var target_dir = base_path.path_join(sub_folder)
			var full_path = target_dir.path_join(entry["file_name"] + ".tres")
			var error = ResourceSaver.save(res, full_path)
func _create_unit(data: Dictionary) -> UnitData:
	var u = UnitData.new()
	var stats = data.get("stats", {})
func _create_building(data: Dictionary) -> BuildingData:
	var b = EconomicBuildingData.new() 
	var stats = data.get("stats", {})
func _ensure_dir(path: String):
```

### `res:///tools/AIContentImporter_Template.gd`
```gdscript
extends EditorScript
const SAVE_DIR_UNITS = "res://data/units/generated/"
const SAVE_DIR_BUILDINGS = "res://data/buildings/generated/"
var RAW_DATA = [
func _run():
	var count = 0
		var res: Resource
		var path: String
			var error = ResourceSaver.save(res, path)
func _create_unit(data: Dictionary) -> UnitData:
	var u = UnitData.new()
	var stats = data.get("stats", {})
func _create_building(data: Dictionary) -> BuildingData:
	var b = EconomicBuildingData.new() 
	var stats = data.get("stats", {})
func _ensure_dir(path: String):
```

### `res:///tools/ContextGenerator_Gemini.gd`
```gdscript
extends EditorScript
const OUTPUT_DIR = "res://_context_dumps"
const OUTPUT_FILENAME = "gemini_api_map.md" # Changed to .md
const IGNORE_DIRS = [
const INCLUDE_EXTENSIONS = ["gd", "tscn", "tres"]
const MAX_FILE_SIZE_BYTES = 1024 * 1024 
const SKIP_RESOURCE_TYPES = [
var _preload_map = {} 
func _run() -> void:
	var time_start = Time.get_ticks_msec()
	var out_path = OUTPUT_DIR + "/" + OUTPUT_FILENAME
	var file = FileAccess.open(out_path, FileAccess.WRITE)
	var all_files = _get_all_files("res://")
	var gd_files: Array[String] = []
	var tscn_files: Array[String] = []
	var tres_files: Array[String] = []
	var buffer: Array[String] = []
		var res_text = _parse_resource(p)
	var elapsed = (Time.get_ticks_msec() - time_start) / 1000.0
func _write_architecture(out: Array):
	var found = false
			var name = prop.name.trim_prefix("autoload/")
			var path = ProjectSettings.get_setting(prop.name).replace("*", "")
		var layer = ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % i)
func _parse_script(path: String) -> String:
	var f = FileAccess.open(path, FileAccess.READ)
	var lines: Array[String] = []
	var local_preloads = []
		var line = f.get_line()
		var s = line.strip_edges()
			var dep = _extract_preload(line)
		var is_structure = false
		elif "func " in s: 
func _parse_scene(path: String) -> String:
	var f = FileAccess.open(path, FileAccess.READ)
	var nodes = {} 
	var connections = []
	var ext_res = {} 
		var line = f.get_line().strip_edges()
			var id = _get_attr(line, "id")
			var p = _get_attr(line, "path")
			var name = _get_attr(line, "name")
			var type = _get_attr(line, "type")
			var parent = _get_attr(line, "parent")
			var script_id = _extract_res_id(line)
			var script_path = ""
			var full_path = name if parent == "." else parent + "/" + name
			var sig = _get_attr(line, "signal")
			var from = _get_attr(line, "from")
			var to = _get_attr(line, "to")
			var method = _get_attr(line, "method")
	var roots = []
		var n = nodes[p]
	var out: Array[String] = []
	var tree_str = "\n".join(out)
	var signal_str = ""
		signal_str = "\n**Signals:**\n" + "\n".join(connections)
func _print_tree(nodes: Dictionary, key: String, depth: int, out: Array):
	var n = nodes[key]
	var indent = "  ".repeat(depth)
	var s_info = " (`%s`)" % n.script if n.script else ""
func _parse_resource(path: String) -> String:
	var f = FileAccess.open(path, FileAccess.READ)
	var type_line = ""
	var content = []
	var is_filtered = false
		var line = f.get_line()
			var type = _get_attr(line, "type")
	var clean_lines: Array[String] = []
		var s = content[i].strip_edges()
func _write_dependencies(out: Array):
func _get_all_files(path: String) -> Array:
	var res = []
	var dir = DirAccess.open(path)
		var n = dir.get_next()
					var full = path + "/" + n
					var skip = false
func _get_attr(line: String, attr: String) -> String:
	var start = line.find(attr + "=")
	var quote = '"'
	var end = line.find(quote, start + 1)
func _extract_res_id(line: String) -> String:
	var i = line.find("ExtResource(")
	var sub = line.substr(i)
	var quote = '"'
	var start = sub.find(quote) + 1
	var end = sub.find(quote, start)
func _extract_preload(line: String) -> String:
	var i = line.find("preload(")
	var sub = line.substr(i)
	var quote = '"'
	var start = sub.find(quote) + 1
	var end = sub.find(quote, start)
```

### `res:///tools/ContextGenerator_NotebookLM.gd`
```gdscript
extends EditorScript
const OUTPUT_PATH = "res://_context_dumps/_NBLM_FULL_SOURCE.txt" 
const SCAN_DIRS = ["res://"]
const IGNORE_DIRS = [
const INCLUDE_EXTENSIONS = ["gd", "tscn", "tres"]
func _run() -> void:
	var time_start = Time.get_ticks_msec()
	var file = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	var all_files = _get_all_files("res://")
	var elapsed = (Time.get_ticks_msec() - time_start) / 1000.0
func _process_file(path: String, f: FileAccess):
	var ext = path.get_extension()
func _write_script_content(path: String, f: FileAccess):
	var content = FileAccess.get_file_as_string(path)
func _write_resource_content(path: String, f: FileAccess):
	var content = FileAccess.get_file_as_string(path)
func _write_scene_smart(path: String, f: FileAccess):
	var content = FileAccess.get_file_as_string(path)
func _get_all_files(path: String) -> Array:
	var res = []
	var dir = DirAccess.open(path)
		var n = dir.get_next()
					var full = path + "/" + n
					var skip = false
```

### `res:///tools/EditorOnly.gd`
```gdscript
extends EditorScript
const SCENE_PATH = "res://scenes/world_map/MacroMap.tscn"
const NAME_MAP = {
func _run():
	var scene = load(SCENE_PATH).instantiate()
	var regions_root = scene.get_node_or_null("Regions")
	var count = 0
		var region_node = regions_root.get_node_or_null(node_name)
			var new_name = NAME_MAP[node_name]
		var packed = PackedScene.new()
		var err = ResourceSaver.save(packed, SCENE_PATH)
```

### `res:///tools/EnemyBaseEditor.gd`
```gdscript
extends EditorScript
func _run():
	var settlement_path = "res://data/settlements/monastery_base.tres"
	var settlement_data: SettlementData = load(settlement_path)
		var building = settlement_data.placed_buildings[i]
		var pos = building["grid_position"]
		var building_data: BuildingData = load(building["resource_path"])
		var name = building_data.display_name if building_data else "Unknown"
static func create_enemy_base_layout(buildings: Array[Dictionary], save_path: String):
	var settlement = SettlementData.new()
static func create_fortress_layout():
	var buildings = [
```

### `res:///tools/GenerateBandContent.gd`
```gdscript
extends EditorScript
func _run():
	var bondi_data = UnitData.new()
	var source_path = "res://scenes/units/PlayerVikingRaider.tscn"
		var base_scene = load(source_path).instantiate()
		var packed = PackedScene.new()
```

### `res:///tools/GenerateRaidMap.gd`
```gdscript
extends EditorScript
const TARGET_PATH = "res://data/settlements/generated/raid_rich_hub_01.tres"
const GRID_W = 80 
const GRID_H = 50
const BEACH_WIDTH = 15 
const B_HALL = "res://data/buildings/GreatHall.tres"
const B_WALL = "res://data/buildings/Bldg_Wall.tres"
const B_TOWER = "res://data/buildings/Monastery_Watchtower.tres"
const RICH_BUILDINGS = [
const MID_BUILDINGS = [
const POOR_BUILDINGS = [
var occupied_cells: Dictionary = {}
var placed_list: Array[Dictionary] = []
func _run() -> void:
	var center = Vector2i(int(GRID_W * 0.7), int(GRID_H * 0.5))
func _reset() -> void:
func _generate_citadel_layer(center: Vector2i, radius_min: int, radius_max: int) -> void:
			var pos = Vector2i(x, y)
			var dist = Vector2(pos).distance_to(Vector2(center))
	var attempts = 20
		var building = RICH_BUILDINGS.pick_random()
		var offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(radius_min, radius_max - 2)
		var pos = center + Vector2i(offset)
func _generate_scatter_layer(center: Vector2i, r_min: int, r_max: int, palette: Array, density: float) -> void:
			var pos = Vector2i(x, y)
			var dist = Vector2(pos).distance_to(Vector2(center))
					var b = palette.pick_random()
func _try_place(path: String, grid_pos: Vector2i) -> void:
	var data = load(path) as BuildingData
	var size = data.grid_size
			var check = grid_pos + Vector2i(x, y)
func _place_building(path: String, grid_pos: Vector2i) -> void:
	var data = load(path) as BuildingData
	var size = data.grid_size
func _save_resource() -> void:
	var dir = TARGET_PATH.get_base_dir()
	var s_data = SettlementData.new()
	var err = ResourceSaver.save(s_data, TARGET_PATH)
```

### `res:///tools/LevelExporter.gd`
```gdscript
extends EditorScript
const TARGET_SAVE_PATH = "res://data/settlements/new_raid_map.tres"
const CONTAINER_NAME = "BuildingContainer"
const CELL_SIZE = Vector2(32, 32)
func _run():
	var root = EditorInterface.get_edited_scene_root()
	var container = root.get_node_or_null(CONTAINER_NAME)
	var settlement_data = SettlementData.new()
	var buildings = container.get_children()
	var count = 0
			var building_size_px = Vector2(node.data.grid_size) * CELL_SIZE
			var top_left_pos = node.position - (building_size_px / 2.0)
			var grid_x = round(top_left_pos.x / CELL_SIZE.x)
			var grid_y = round(top_left_pos.y / CELL_SIZE.y)
			var grid_pos = Vector2i(grid_x, grid_y)
			var entry = {
	var error = ResourceSaver.save(settlement_data, TARGET_SAVE_PATH)
```

### `res:///tools/Raid_prep_generatory.gd`
```gdscript
extends EditorScript
const SCENE_PATH = "res://ui/RaidPrepWindow.tscn"
const SCRIPT_PATH = "res://ui/RaidPrepWindow.gd"
func _run() -> void:
	var root = PanelContainer.new()
	var script = load(SCRIPT_PATH)
	var margin = MarginContainer.new()
	var main_vbox = VBoxContainer.new()
	var header = Label.new()
	var sep1 = HSeparator.new()
	var content_hbox = HBoxContainer.new()
	var left_col = VBoxContainer.new()
	var target_name = Label.new()
	var desc_label = RichTextLabel.new()
	var stats_grid = GridContainer.new()
	var vsep = VSeparator.new()
	var right_col = VBoxContainer.new()
	var cap_label = Label.new()
	var scroll = ScrollContainer.new()
	var warband_list = VBoxContainer.new()
	var bondi_panel = PanelContainer.new()
	var bondi_vbox = VBoxContainer.new()
	var bondi_label = Label.new()
	var bondi_slider_box = HBoxContainer.new()
	var bondi_slider = HSlider.new()
	var bondi_count_lbl = Label.new()
	var sep2 = HSeparator.new()
	var prov_panel = PanelContainer.new()
	var prov_hbox = HBoxContainer.new()
	var l_supplies = Label.new()
	var slider = HSlider.new()
	var cost_l = Label.new()
	var eff_l = Label.new()
	var actions = HBoxContainer.new()
	var btn_cancel = Button.new()
	var btn_launch = Button.new()
	var packed_scene = PackedScene.new()
	var error = ResourceSaver.save(packed_scene, SCENE_PATH)
func _add_stat_row(parent, owner, label_name, label_text, val_name, val_text):
	var l = Label.new()
	var v = Label.new()
```

### `res:///tools/SceneGeneratorTool.gd`
```gdscript
extends EditorScript
func _run() -> void:
	var paths = [
			var data = load(path) as UnitData
```

### `res:///tools/SettlementLayoutEditor.gd`
```gdscript
extends EditorScript
const BUILDINGS = {
func _run():
	var small_defensive = create_small_defensive_layout()
	var economic = create_economic_layout()
	var monastery = create_monastery_layout()
func create_small_defensive_layout() -> Array[Dictionary]:
func create_economic_layout() -> Array[Dictionary]:
func create_monastery_layout() -> Array[Dictionary]:
func print_layout(layout: Array[Dictionary]):
		var building = layout[i]
		var name = get_building_name(building["resource_path"])
		var pos = building["grid_position"]
func get_building_name(path: String) -> String:
func save_layout(layout: Array[Dictionary], path: String):
	var settlement = SettlementData.new()
	var error = ResourceSaver.save(settlement, path)
```

### `res:///tools/TestPopulationLogic.gd`
```gdscript
extends EditorScript
const FOOD_PER_PERSON = 10
const BASE_GROWTH = 0.02
const STARVATION_RATE = -0.15
const UNREST_PER_EXCESS = 2
func _run():
func _test_scenario(title: String, pop: int, food: int, land_cap: int) -> void:
	var food_req = pop * FOOD_PER_PERSON
	var growth_rate = BASE_GROWTH
	var status = "Normal"
	var net_change = int(pop * growth_rate)
	var new_pop = pop + net_change
		var excess = new_pop - land_cap
		var unrest = excess * UNREST_PER_EXCESS
```

### `res:///tools/ThemeBuilder.gd`
```gdscript
extends EditorScript
const THEME_PATH = "res://ui/themes/VikingDynastyTheme.tres"
const ASSET_PATH = "res://ui/assets/"
const FONT_PATH = "res://assets/fonts/"
const COL_INK = Color("#2b221b")
const COL_PARCHMENT = Color("#f5e6d3")
const COL_GOLD = Color("#c5a54e")
func _run() -> void:
	var theme = Theme.new()
	var font_header = _try_load_font("UncialAntiqua-Regular.ttf")
	var font_body = _try_load_font("CrimsonText-Regular.ttf")
	var wood_tex = load(ASSET_PATH + "wood_bg.png")
		var style_normal = StyleBoxTexture.new()
		var style_hover = style_normal.duplicate()
		var style_pressed = style_normal.duplicate()
		var style_disabled = style_normal.duplicate()
	var parchment_tex = load(ASSET_PATH + "parchment_bg.png")
		var style_panel = StyleBoxTexture.new()
	var tag_tex = load(ASSET_PATH + "resource_tag.png")
		var style_tag = StyleBoxTexture.new()
	var tooltip_tex = load(ASSET_PATH + "tooltip_bg.png")
		var style_tooltip = StyleBoxTexture.new()
	var error = ResourceSaver.save(theme, THEME_PATH)
func _try_load_font(filename: String) -> Font:
	var path = FONT_PATH + filename
```

### `res:///ui/DynastyUI.gd`
```gdscript
class_name DynastyUI
extends PanelContainer
@onready var ancestors_container: HBoxContainer = $Margin/MainLayout/AncestorsScroll/AncestorsHBox
@onready var current_jarl_name: Label = $Margin/MainLayout/CurrentJarlPanel/Stats/NameLabel
@onready var current_jarl_stats: Label = $Margin/MainLayout/CurrentJarlPanel/Stats/StatsLabel
@onready var current_jarl_portrait: TextureRect = $Margin/MainLayout/CurrentJarlPanel/Portrait
@onready var heirs_container: HBoxContainer = $Margin/MainLayout/HeirsScroll/HeirsHBox
@onready var close_button: Button = $Margin/MainLayout/CloseButton
@onready var context_menu: PopupMenu = $ContextMenu
const HEIR_CARD_SCENE = preload("res://ui/components/HeirCard.tscn")
const PLACEHOLDER_ICON = preload("res://textures/placeholders/unit_placeholder.png")
var selected_heir: JarlHeirData
func _ready() -> void:
func _on_visibility_changed() -> void:
func _on_jarl_stats_updated(jarl: JarlData) -> void:
	var prowess = jarl.get_effective_skill("prowess")
	var stewardship = jarl.get_effective_skill("stewardship")
	var command = jarl.get_effective_skill("command")
	var learning = jarl.get_effective_skill("learning")
	var stats_text = "Age: %d  |  Renown: %d  |  Authority: %d/%d\n" % [jarl.age, jarl.renown, jarl.current_authority, jarl.max_authority]
func _populate_ancestors(ancestors_data: Array) -> void:
		var texture = TextureRect.new()
func _populate_heirs(heirs_data: Array[JarlHeirData]) -> void:
		var card = HEIR_CARD_SCENE.instantiate()
func _on_heir_card_clicked(heir: JarlHeirData, mouse_pos: Vector2) -> void:
func _on_context_menu_item_pressed(id: int) -> void:
			var cost = {"gold": 500}
func _on_close_button_pressed() -> void:
func _input(event: InputEvent) -> void:
func _open_warband_assignment_dialog() -> void:
	var settlement = SettlementManager.current_settlement
```

### `res:///ui/EndOfYear_Popup.gd`
```gdscript
extends PanelContainer
signal collect_button_pressed(payout: Dictionary)
@onready var payout_label: RichTextLabel = $MarginContainer/VBoxContainer/PayoutLabel
@onready var collect_button: Button = $MarginContainer/VBoxContainer/CollectButton
@onready var loot_panel: PanelContainer = %LootDistributionPanel
@onready var loot_slider: HSlider = %LootSlider
@onready var result_label: Label = %DistributionResultLabel
var _base_payout: Dictionary = {}
var _final_payout: Dictionary = {}
var _total_loot_gold: int = 0
func _ready() -> void:
func display_payout(payout: Dictionary, title: String = "Welcome home!") -> void:
	var is_raid = title.contains("Raid") or title.contains("Victory")
func _update_distribution_preview(percent_shared: float) -> void:
	var share_pct = percent_shared / 100.0
	var gold_shared = int(_total_loot_gold * share_pct)
	var gold_kept = _total_loot_gold - gold_shared
	var renown_change = 0
		var sign_str = "+" if renown_change > 0 else ""
func _update_text_display(title: String) -> void:
	var text: String = "[b]%s[/b]\n\n" % title
		var val = _base_payout[key]
			var col = "green" if val > 0 else "salmon" # Brighter red
func _on_collect_pressed() -> void:
```

### `res:///ui/Event_UI.gd`
```gdscript
class_name EventUI
extends CanvasLayer
signal choice_made(event: EventData, choice: EventChoice)
@onready var title_label: Label = $PanelContainer/Margin/VBox/TitleLabel
@onready var description_label: Label = $PanelContainer/Margin/VBox/HBox/DescriptionLabel
@onready var portrait: TextureRect = %Portrait
@onready var choice_buttons_container: VBoxContainer = $PanelContainer/Margin/VBox/ChoiceButtonsContainer
var current_event: EventData
func _ready() -> void:
func display_event(event_data: EventData) -> void:
		var ok_button = Button.new()
			var choice_button = Button.new()
	var first_button = choice_buttons_container.get_child(0) as Button
func _on_choice_button_pressed(choice: EventChoice) -> void:
```

### `res:///ui/PauseButton.gd`
```gdscript
extends Button
func _ready():
func _unhandled_input(event: InputEvent) -> void:
func _on_pause_pressed():
		var pause_manager = get_node_or_null("/root/PauseManager")
func _create_simple_pause_menu():
		var existing_overlay = get_tree().get_first_node_in_group("pause_overlay")
	var pause_overlay = ColorRect.new()
	var vbox = VBoxContainer.new()
	var title_label = Label.new()
	var resume_button = Button.new()
	var quit_button = Button.new()
func _resume_game():
	var existing_overlay = get_tree().get_first_node_in_group("pause_overlay")
func _quit_to_menu():
```

### `res:///ui/RaidPrepWindow.gd`
```gdscript
class_name RaidPrepWindow
extends PanelContainer
signal raid_launched(target: RaidTargetData, warbands: Array[WarbandData], provision_level: int)
signal closed
@onready var target_name_label: Label = $MarginContainer/MainVBox/ContentHBox/LeftCol/TargetNameLabel
@onready var description_label: RichTextLabel = $MarginContainer/MainVBox/ContentHBox/LeftCol/DescriptionLabel
@onready var val_diff: Label = $MarginContainer/MainVBox/ContentHBox/LeftCol/StatsGrid/ValDiff
@onready var val_cost: Label = $MarginContainer/MainVBox/ContentHBox/LeftCol/StatsGrid/ValCost
@onready var capacity_label: Label = $MarginContainer/MainVBox/ContentHBox/RightCol/CapacityLabel
@onready var warband_list: VBoxContainer = $MarginContainer/MainVBox/ContentHBox/RightCol/ScrollContainer/WarbandList
@onready var provision_slider: HSlider = $MarginContainer/MainVBox/ProvisionsPanel/HBox/ProvisionSlider
@onready var cost_label: Label = $MarginContainer/MainVBox/ProvisionsPanel/HBox/CostLabel
@onready var effect_label: Label = $MarginContainer/MainVBox/ProvisionsPanel/HBox/EffectLabel
@onready var launch_button: Button = $MarginContainer/MainVBox/ActionButtons/LaunchButton
@onready var cancel_button: Button = $MarginContainer/MainVBox/ActionButtons/CancelButton
@onready var bondi_slider: HSlider = $MarginContainer/MainVBox/ContentHBox/RightCol/BondiPanel/BondiVBox/BondiSliderBox/BondiSlider
@onready var bondi_count_label: Label = $MarginContainer/MainVBox/ContentHBox/RightCol/BondiPanel/BondiVBox/BondiSliderBox/BondiCountLabel
var current_target: RaidTargetData
var selected_warbands: Array[WarbandData] = []
var max_capacity: int = 0
var current_provision_level: int = 1
var calculated_food_cost: int = 0
var available_idle_peasants: int = 0
const FOOD_COST_PER_HEAD_WELL_FED = 25
const BONDI_UNIT_DATA_PATH = "res://data/units/Unit_Bondi.tres"
func _ready() -> void:
func setup(target: RaidTargetData) -> void:
	var auth_cost = target.raid_cost_authority
func _populate_warband_list() -> void:
	var warbands = SettlementManager.current_settlement.warbands
		var checkbox = CheckBox.new()
func _on_warband_toggled(is_checked: bool, warband: WarbandData, checkbox_node: CheckBox) -> void:
func _on_bondi_slider_changed(_value: float) -> void:
func _update_bondi_ui() -> void:
	var count = int(bondi_slider.value)
func _get_total_fleet_usage() -> int:
	var slots = selected_warbands.size()
	var bondi_count = int(bondi_slider.value)
		var bondi_bands = ceil(float(bondi_count) / WarbandData.MAX_MANPOWER)
func _update_capacity_ui() -> void:
	var usage = _get_total_fleet_usage()
func _validate_launch_readiness() -> void:
	var cost = current_target.raid_cost_authority
	var current_food = SettlementManager.current_settlement.treasury.get(GameResources.FOOD, 0)
func _on_launch_pressed() -> void:
	var bondi_count = int(bondi_slider.value)
func _create_and_append_bondi(count: int) -> void:
	var unit_data = load(BONDI_UNIT_DATA_PATH)
	var remaining = count
		var batch_size = min(remaining, WarbandData.MAX_MANPOWER)
		var bondi_band = WarbandData.new(unit_data)
func _on_cancel_pressed() -> void:
func _update_provision_cost() -> void:
	var total_men = 0
func _on_provision_slider_changed(value: float) -> void:
func _update_provision_ui() -> void:
func _shake_capacity_label() -> void:
	var tween = create_tween()
	var original_pos = capacity_label.position.x
```

### `res:///ui/SelectionBox.gd`
```gdscript
extends Control
var is_dragging := false
var start_pos := Vector2.ZERO
var is_command_dragging := false
var command_start_pos := Vector2.ZERO
func _ready() -> void:
func _gui_input(event: InputEvent) -> void:
				var end_pos := get_local_mouse_position()
				var rect := Rect2(start_pos, end_pos - start_pos).abs()
				var is_box_select = rect.size.length_squared() > 100
				var end_pos = get_local_mouse_position()
				var drag_vector = end_pos - command_start_pos
					var main_camera = get_viewport().get_camera_2d()
						var world_end = main_camera.get_global_mouse_position()
						var world_start = world_end - (drag_vector / main_camera.zoom)
						var dir = (world_end - world_start).normalized()
func _handle_smart_command(_screen_pos: Vector2) -> void:
	var world_space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var main_camera: Camera2D = get_viewport().get_camera_2d()
	var world_pos: Vector2 = main_camera.get_global_mouse_position()
	var query := PhysicsPointQueryParameters2D.new()
	var results: Array = world_space.intersect_point(query)
		var hit_object = results[0].collider
		var final_target = hit_object
func _try_select_building(screen_pos: Vector2) -> bool:
	var world_space = get_world_2d().direct_space_state
	var main_camera = get_viewport().get_camera_2d()
	var world_pos = main_camera.get_global_mouse_position()
	var query = PhysicsPointQueryParameters2D.new()
	var results = world_space.intersect_point(query)
		var collider = res.collider
func _draw() -> void:
		var current_pos := get_local_mouse_position()
		var rect := Rect2(start_pos, current_pos - start_pos).abs()
		var current_pos := get_local_mouse_position()
```

### `res:///ui/StorefrontUI.gd`
```gdscript
extends Control
const LegacyUpgradeData = preload("res://data/legacy/LegacyUpgradeData.gd")
const RICH_TOOLTIP_SCRIPT = preload("res://ui/components/RichTooltipButton.gd")
const WINTER_FOOD_PER_PEASANT: int = 1
const WINTER_FOOD_PER_WARBAND: int = 5
const WINTER_WOOD_BASE_COST: int = 20
@onready var build_window: Control = %BuildWindow
@onready var recruit_window: Control = %RecruitWindow
@onready var legacy_window: Control = %LegacyWindow
@onready var build_grid: Container = %BuildGrid
@onready var recruit_list: Container = %RecruitList
@onready var legacy_list: Container = %LegacyList
@onready var renown_label: Label = %RenownLabel
@onready var authority_label: Label = %AuthorityLabel
@onready var btn_build: Button = %Btn_Build
@onready var btn_recruit: Button = %Btn_Recruit
@onready var btn_upgrades: Button = %Btn_LegacyUpgrades
@onready var btn_family: Button = %Btn_Family
@onready var btn_map: Button = %Btn_Map
@onready var btn_end_year: Button = %Btn_EndYear
@onready var btn_allocation: Button = %Btn_Allocation
@onready var date_label: Label = %DateLabel
@export var available_buildings: Array[BuildingData] = []
@export var available_units: Array[UnitData] = []
@export var auto_load_units_from_directory: bool = true
var pending_cost: Dictionary = {} 
func _ready() -> void:
func _on_units_selected(selected_units: Array) -> void:
	var has_builder = false
func _update_end_year_tooltip(season_name: String) -> void:
	var next_season_name = "Spring"
	var action_text = "Advance to %s" % next_season_name
	var tooltip = "[b]%s[/b]" % action_text
		var s = SettlementManager.current_settlement
		var yearly: Dictionary[String, int] = EconomyManager.get_projected_income()
		var has_gains = false
		var has_potential_but_no_workers = false
			var amount = 0
				var is_full = EconomyManager.is_storage_full(res)
				var display_text = ""
					var color = "green"
			var forecast = EconomyManager.get_winter_forecast()
			var food_demand = forecast["food"]
			var wood_demand = forecast["wood"]
			var current_food = s.treasury.get("food", 0)
			var food_col = "orange"
			var current_wood = s.treasury.get("wood", 0)
			var wood_col = "orange"
func _on_season_changed(season_name: String) -> void:
func _update_date_display(season_name: String) -> void:
		var year = DynastyManager.current_year
func _populate_build_grid() -> void:
		var btn = Button.new()
		var details = ""
			var eco = b_data as EconomicBuildingData
				var cursor = get_tree().get_first_node_in_group("building_preview_cursor")
func _on_placement_cancelled() -> void:
func _on_placement_completed() -> void:
func _setup_dock_icons() -> void:
func _set_btn_icon(btn: Button, path: String) -> void:
func _setup_window_logic() -> void:
	var windows = [build_window, recruit_window, legacy_window]
func _toggle_window(target_window: Control) -> void:
func _close_all_windows() -> void:
func _refresh_all() -> void:
func _on_purchase_successful(_item: String) -> void:
func _on_purchase_failed(reason: String) -> void:
func _show_toast(text: String, color: Color) -> void:
	var label = Label.new()
	var tween = create_tween()
func _on_settlement_loaded(_data: SettlementData) -> void:
func _on_year_ended() -> void:
func _update_jarl_stats_display(jarl_data: JarlData) -> void:
func _update_garrison_display() -> void:
		var header = Label.new()
		var sep = HSeparator.new()
		var header2 = Label.new()
			var btn = Button.new()
func _create_warband_entry(warband: WarbandData) -> void:
	var row = HBoxContainer.new()
	var lbl = RichTextLabel.new()
	var jarl_name = "Jarl"
		var btn = Button.new()
	var guard = Button.new()
func _populate_legacy_buttons() -> void:
		var label = Label.new()
	var jarl = DynastyManager.get_current_jarl()
	var is_pious = jarl.has_trait("Pious")
		var current_renown_cost = upgrade_data.renown_cost
		var btn = Button.new()
		var cost_text = "Cost: %d Renown, %d Auth" % [current_renown_cost, upgrade_data.authority_cost]
func _load_building_data() -> void:
func _scan_directory_for_buildings(path: String) -> void:
	var dir = DirAccess.open(path)
		var file = dir.get_next()
				var full_path = path + file
				var data = load(full_path)
func _load_unit_data() -> void:
	var dir = DirAccess.open("res://data/units/")
		var file = dir.get_next()
				var data = load("res://data/units/" + file)
func _format_cost(cost: Dictionary) -> String:
	var s: PackedStringArray = []
		var display_name = GameResources.get_display_name(k)
func _apply_theme_overrides() -> void:
	var tooltip_bg_path = "res://ui/assets/tooltip_bg.png"
	var default_theme_path = "res://ui/themes/VikingDynastyTheme.tres"
		var tooltip_tex = load(tooltip_bg_path)
		var style_tooltip = StyleBoxTexture.new()
```

### `res:///ui/Succession_Crisis_UI.gd`
```gdscript
extends CanvasLayer
@onready var panel_container: PanelContainer = $PanelContainer # Added for centering logic
@onready var desc_label = $PanelContainer/MarginContainer/VBoxContainer/DescriptionLabel
@onready var legit_label = $PanelContainer/MarginContainer/VBoxContainer/LegitimacyLabel
@onready var renown_desc = $PanelContainer/MarginContainer/VBoxContainer/RenownTaxDescription
@onready var gold_desc = $PanelContainer/MarginContainer/VBoxContainer/GoldTaxDescription
@onready var pay_renown_btn = $PanelContainer/MarginContainer/VBoxContainer/RenownTaxButtons/PayRenownButton
@onready var refuse_renown_btn = $PanelContainer/MarginContainer/VBoxContainer/RenownTaxButtons/RefuseRenownButton
@onready var pay_gold_btn = $PanelContainer/MarginContainer/VBoxContainer/GoldTaxButtons/PayGoldButton
@onready var refuse_gold_btn = $PanelContainer/MarginContainer/VBoxContainer/GoldTaxButtons/RefuseGoldButton
@onready var confirm_btn = $PanelContainer/MarginContainer/VBoxContainer/ConfirmButton
var renown_tax: int = 0
var gold_tax: int = 0
var renown_choice: String = "pay"
var gold_choice: String = "pay"
func _ready() -> void:
	var renown_group = ButtonGroup.new()
	var gold_group = ButtonGroup.new()
func display_crisis(jarl: JarlData, settlement: SettlementData) -> void:
	var legitimacy = jarl.legitimacy
	var tax_multiplier = 1.0 - (legitimacy / 100.0) # 100 legit = 0x, 20 legit = 0.8x
func _on_renown_choice(choice: String) -> void:
func _on_gold_choice(choice: String) -> void:
func _on_confirm() -> void:
```

### `res:///ui/WorkAssignment_UI.gd`
```gdscript
extends CanvasLayer
signal assignments_confirmed(assignments: Dictionary)
@onready var total_pop_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/TotalPopLabel
@onready var available_pop_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/AvailablePopLabel
@onready var sliders_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/SlidersContainer
@onready var confirm_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ConfirmButton
var prediction_label: RichTextLabel
var current_settlement: SettlementData
var temp_assignments: Dictionary = {}
var total_population: int = 0
var available_population: int = 0
var labor_capacities: Dictionary = {} 
var sliders: Dictionary = {} 
var labels: Dictionary = {}  
func _ready() -> void:
	var container = $PanelContainer/MarginContainer/VBoxContainer
func setup(settlement: SettlementData) -> void:
func _rebuild_ui() -> void:
	var categories = ["construction", "food", "wood", "stone"]
func _create_slider_row(category: String) -> void:
	var row = HBoxContainer.new()
	var name_label = Label.new()
	var capacity = labor_capacities.get(category, 0)
	var max_assignable = min(total_population, capacity)
	var slider = HSlider.new()
	var value_label = Label.new()
func _on_slider_changed(value: float, category: String) -> void:
	var new_val = int(value)
	var current_usage = 0
func _update_calculations() -> void:
	var assigned_count = 0
			var capacity = labor_capacities.get(key, 0)
		var prediction = SettlementManager.simulate_turn(temp_assignments)
func _update_prediction_display(data: Dictionary) -> void:
	var text = "[b]Estimated Outcome:[/b]\n"
	var res = data.get("resources_gained", {})
	var res_str = ""
			var color_tag = "[color=white]"
	var completed = data.get("buildings_completing", [])
func _on_confirm_pressed() -> void:
```

### `res:///ui/components/BuildingInfoHUD.gd`
```gdscript
extends Control
class_name BuildingInfoHUD
@onready var name_label: Label = $Background/MarginContainer/NameLabel
@onready var health_bar: ProgressBar = $HealthBar
@onready var background: PanelContainer = $Background
@onready var status_icon: TextureRect = $StatusIcon
var style_fill: StyleBoxFlat
func _ready() -> void:
func setup(display_name: String, size_pixels: Vector2) -> void:
func update_health(current: int, max_hp: int) -> void:
func update_construction(current: int, required: int) -> void:
	var percent = int((float(current) / required) * 100)
func set_blueprint_mode() -> void:
func set_active_mode(display_name: String) -> void:
func hide_progress() -> void:
```

### `res:///ui/components/BuildingInspector.gd`
```gdscript
extends PanelContainer
@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var stats_label: RichTextLabel = %StatsLabel
@onready var worker_count_label: Label = %WorkerCountLabel
@onready var btn_add: Button = %BtnAdd
@onready var btn_remove: Button = %BtnRemove
var current_building: BaseBuilding
var current_entry: Dictionary 
func _ready() -> void:
func _on_building_selected(building: BaseBuilding) -> void:
func _refresh_data() -> void:
	var data = current_building.data
	var p_count = current_entry.get("peasant_count", 0)
	var capacity = 0
	var text = ""
			var eco = data as EconomicBuildingData
			var production = (eco.base_passive_output * p_count) 
		var progress = current_entry.get("progress", 0)
		var req = data.construction_effort_required
		var pct = 0
		var labor_per_year = p_count * EconomyManager.BUILDER_EFFICIENCY
			var remaining = req - progress
			var years = ceil(float(remaining) / labor_per_year)
	var can_add = p_count < capacity
func _on_add_worker() -> void:
func _on_remove_worker() -> void:
```

### `res:///ui/components/HeirCard.gd`
```gdscript
extends PanelContainer
class_name HeirCard
signal card_clicked(heir_data: JarlHeirData, global_pos: Vector2)
@onready var portrait_rect: TextureRect = $VBox/PortraitContainer/Portrait
@onready var status_icon: TextureRect = $VBox/PortraitContainer/StatusIcon
@onready var heir_crown_icon: TextureRect = $VBox/PortraitContainer/HeirCrown
@onready var name_label: Label = $VBox/NameLabel
@onready var stats_label: Label = $VBox/StatsLabel
var heir_data: JarlHeirData
func setup(data: JarlHeirData) -> void:
	var trait_text = "None"
func _update_status_visuals() -> void:
func _gui_input(event: InputEvent) -> void:
```

### `res:///ui/components/RichTooltipButton.gd`
```gdscript
class_name RichTooltipButton
extends Button
func _make_custom_tooltip(for_text: String) -> Object:
	var panel = PanelContainer.new()
		var ui_node: Node = self
	var rtl = RichTextLabel.new()
```

### `res:///ui/components/TreasuryHUD.gd`
```gdscript
class_name TreasuryHUD
extends PanelContainer
@onready var gold_label: Label = %GoldLabel
@onready var wood_label: Label = %WoodLabel
@onready var food_label: Label = %FoodLabel
@onready var stone_label: Label = %StoneLabel
@onready var pop_label: Label = %PeasantLabel
@onready var thrall_label: Label = %ThrallLabel
@onready var unit_count_label: Label = %UnitCountLabel
func _ready() -> void:
func _refresh_from_manager() -> void:
func _update_treasury_display(treasury: Dictionary) -> void:
		var idle_p = SettlementManager.get_idle_peasants()
		var total_p = SettlementManager.current_settlement.population_peasants
		var idle_t = SettlementManager.get_idle_thralls()
		var total_t = SettlementManager.current_settlement.population_thralls
```

### `res:///ui/components/WorkerTag.gd`
```gdscript
class_name WorkerTag
extends Control
var building_index: int = -1
var is_pending: bool = false # NEW FLAG
var caps = {"peasant": 0, "thrall": 0}
@onready var lbl_peasant = $Panel/VBox/HBox_Peasant/CountLabel
@onready var lbl_thrall = $Panel/VBox/HBox_Thrall/CountLabel
func _ready() -> void:
func setup(idx: int, p_count: int, p_cap: int, t_count: int, t_cap: int, _pending: bool = false) -> void:
func _on_mod(type: String, amount: int) -> void:
func _update_labels(p_val: int, t_val: int) -> void:
```

### `res:///ui/seasonal/SeasonalCard_UI.gd`
```gdscript
class_name SeasonalCard_UI
extends Control
signal card_clicked(card_data: SeasonalCardResource)
@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var icon_rect: TextureRect = %IconRect
@onready var cost_container: HBoxContainer = %CostContainer
@onready var ap_cost_label: Label = %APCostLabel # Inside CostContainer
@onready var gold_cost_label: Label = %GoldCostLabel
@onready var select_button: Button = %SelectButton
var _card_data: SeasonalCardResource
func _ready() -> void:
func setup(card: SeasonalCardResource, can_afford: bool = true) -> void:
func _on_button_pressed() -> void:
```

### `res:///ui/seasonal/SpringCouncil_UI.gd`
```gdscript
class_name SpringCouncil_UI
extends Control
@export_group("Deck Configuration")
@export var available_advisor_cards: Array[SeasonalCardResource] = []
@export var hand_size: int = 3
@export_group("References")
@export var card_prefab: PackedScene 
@export var card_container: HBoxContainer
var _selected_card: SeasonalCardResource
var _has_activated: bool = false
func _ready() -> void:
func _on_season_changed(season_name: String) -> void:
func _activate_spring_ui() -> void:
func _on_diagnostic_timeout() -> void:
func _deal_cards() -> void:
	var spring_deck: Array[SeasonalCardResource] = []
		var card = available_advisor_cards[i]
	var cards_to_spawn = min(hand_size, spring_deck.size())
		var card_instance = card_prefab.instantiate() as SeasonalCard_UI
func _on_card_selected(card: SeasonalCardResource) -> void:
func _commit_choice() -> void:
```

### `res:///ui/seasonal/SummerAllocation_UI.gd`
```gdscript
extends Control
@export_group("Configuration")
@export var raider_template: UnitData ## The UnitData resource used for drafted peasants (e.g., Bondi).
@export var estimated_farm_yield: int = 100 ## Estimated yield per farmer if dynamic calculation fails.
const SEASONS_PER_YEAR: int = 4
const SEASON_NAMES: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
const WINTER_FOOD_PER_PEASANT: int = 1 # Used for live projection adjustments
@onready var label_population: Label = %PopulationLabel
@onready var label_unassigned: Label = %UnassignedLabel
@onready var slider_construction: HSlider = %ConstructionSlider
@onready var slider_farming: HSlider = %FarmingSlider
@onready var slider_raiding: HSlider = %RaidingSlider
@onready var val_construction: Label = %ValConstruction
@onready var val_farming: Label = %ValFarming
@onready var val_raiding: Label = %ValRaiding
@onready var proj_construction: Label = %Proj_Construction
@onready var proj_food: Label = %Proj_Food
@onready var proj_raid: Label = %Proj_Raid
@onready var lbl_current_stockpile: Label = %Lbl_Stockpile
@onready var lbl_winter_demand: Label = %Lbl_WinterDemand
@onready var lbl_winter_net: Label = %Lbl_WinterNet
@onready var btn_commit_raid: Button = %CommitRaidBtn
@onready var btn_confirm: Button = %ConfirmBtn
var total_peasants: int = 0
var total_construction_slots: int = 0
var total_farming_slots: int = 0
var allocations: Dictionary = {
var _updating_sliders: bool = false
func _ready() -> void:
func _connect_signals() -> void:
func _on_season_changed(season_name: String) -> void:
func toggle_interface(interface_name: String = "") -> void:
func _initialize_data() -> void:
	var pending = SettlementManager.current_settlement.pending_construction_buildings
			var b_data = load(entry["resource_path"]) as BuildingData
				var cap = b_data.base_labor_capacity if "base_labor_capacity" in b_data else 3
	var placed = SettlementManager.current_settlement.placed_buildings
			var b_data = load(entry["resource_path"])
		var initial_farm = min(int(total_farming_slots * 0.8), total_peasants)
		var remaining = total_peasants - initial_farm
		var initial_const = min(total_construction_slots, remaining)
func _sync_sliders_to_data() -> void:
func _on_allocation_changed(_value: float) -> void:
func _recalculate_slider_limits() -> void:
	var used = allocations.construction + allocations.farming + allocations.raiding
	var free_pop = total_peasants - used
	var potential_const = allocations.construction + free_pop
	var final_max_const = min(potential_const, total_construction_slots)
	var potential_farm = allocations.farming + free_pop
	var final_max_farm = min(potential_farm, total_farming_slots)
	var potential_raid = allocations.raiding + free_pop
func _update_ui() -> void:
	var used = allocations.construction + allocations.farming + allocations.raiding
	var unassigned = total_peasants - used
func _update_projections() -> void:
	var pending = SettlementManager.current_settlement.pending_construction_buildings
		var report = ""
		var assignments = _get_builder_distribution(allocations.construction)
			var entry = pending[i]
			var b_data = load(entry["resource_path"]) as BuildingData
			var assigned_workers = assignments[i]
			var b_name = b_data.display_name if b_data else "Building"
				var total_effort = 100 
				var remaining_effort = max(0, total_effort - entry.get("progress", 0))
				var seasonal_progress = assigned_workers * EconomyManager.BUILDER_EFFICIENCY
					var turns_needed = ceil(float(remaining_effort) / float(seasonal_progress))
					var date_str = _calculate_completion_date(int(turns_needed))
		var yields = _calculate_projected_yields(allocations.farming)
		var food_amt = yields.get("food", 0)
		var other_text = ""
	var men = allocations.raiding
	var bands = ceil(men / 10.0)
func _update_winter_forecast() -> void:
	var forecast = EconomyManager.get_winter_forecast()
	var base_food_demand = forecast.get("food", 0)
	var wood_demand = forecast.get("wood", 0)
	var raiders = allocations.raiding
	var adjusted_food_demand = max(0, base_food_demand - (raiders * WINTER_FOOD_PER_PEASANT))
	var treasury = SettlementManager.current_settlement.treasury
	var current_food = treasury.get("food", 0)
	var current_wood = treasury.get("wood", 0)
	var estimated_yields = _calculate_projected_yields(allocations.farming)
	var projected_food_yield = estimated_yields.get("food", 0)
	var projected_wood_yield = estimated_yields.get("wood", 0)
	var total_food_available = current_food + projected_food_yield
	var total_wood_available = current_wood + projected_wood_yield
	var food_net = total_food_available - adjusted_food_demand
	var wood_net = total_wood_available - wood_demand
	var status_text = ""
	var color = Color.GREEN
func _calculate_completion_date(turns_needed: int) -> String:
	var current_year = 867
	var current_season_idx = DynastyManager.current_season # Enum (0-3)
	var absolute_current_turn = (current_year * SEASONS_PER_YEAR) + current_season_idx
	var absolute_completion_turn = absolute_current_turn + turns_needed
	var future_year = floor(absolute_completion_turn / float(SEASONS_PER_YEAR))
	var future_season_idx = absolute_completion_turn % SEASONS_PER_YEAR
	var season_name = "Unknown"
func _on_confirm_pressed() -> void:
func _get_builder_distribution(total_pool: int) -> Array:
	var results = []
	var remaining = total_pool
	var pending = SettlementManager.current_settlement.pending_construction_buildings
		var b_data = load(entry["resource_path"]) as BuildingData
		var capacity = 3
		var to_assign = min(remaining, capacity)
func _apply_builder_distribution(total_pool: int) -> void:
	var assignments = _get_builder_distribution(total_pool)
	var pending = SettlementManager.current_settlement.pending_construction_buildings
func _calculate_projected_yields(total_farmers: int) -> Dictionary:
	var yields = {}
	var remaining = total_farmers
	var placed = SettlementManager.current_settlement.placed_buildings
	var food_buildings = []
	var other_buildings = []
			var b_data = load(entry["resource_path"])
				var item = {"data": b_data, "cap": b_data.peasant_capacity}
		var assign = min(remaining, item.cap)
		var out = assign * item.data.base_passive_output
		var type = item.data.resource_type
		var assign = min(remaining, item.cap)
		var out = assign * item.data.base_passive_output
		var type = item.data.resource_type
func _distribute_farmers(total_farmers: int) -> void:
	var remaining = total_farmers
	var placed = SettlementManager.current_settlement.placed_buildings
	var food_buildings = []
	var other_buildings = []
		var b_data = load(entry["resource_path"])
		var to_assign = min(remaining, item.cap)
		var to_assign = min(remaining, item.cap)
func _on_commit_raid_pressed() -> void:
	var raid_count = allocations.raiding
func _convert_villagers_to_raiders(count: int) -> void:
	var new_warbands: Array[WarbandData] = []
	var remaining = count
		var batch_size = min(remaining, 10)
		var bondi_band = WarbandData.new(raider_template)
```

## 💾 GAME DATA (Resources)

### `res:///assets/placeholder_tile.tres`
```text
[gd_resource type="NoiseTexture2D" load_steps=2 format=3 uid="uid://c6v2d1q8q7e3j"]
[sub_resource type="FastNoiseLite" id="FastNoiseLite_cemhj"]
noise_type = 2
frequency = 0.1153
[resource]
width = 100
height = 100
noise = SubResource("FastNoiseLite_cemhj")
```

### `res:///data/buildings/Bldg_Wall.tres`
```text
[gd_resource type="Resource" script_class="BuildingData" load_steps=3 format=3 uid="uid://b2356vlfukf14"]
[ext_resource type="Script" uid="uid://js4bbqgeyd6c" path="res://data/buildings/BuildingData.gd" id="1_t76rl"]
[ext_resource type="PackedScene" uid="uid://cws6xle5x52g4" path="res://scenes/buildings/Base_Building.tscn" id="1_vluf5"]
[resource]
script = ExtResource("1_t76rl")
display_name = "Stone Wall"
scene_to_spawn = ExtResource("1_vluf5")
build_cost = {
"stone": 25
}
dev_color = Color(0.050751396, 0.05072763, 0.06304378, 1)
is_player_buildable = true
extends_territory = true
attack_damage = 0
attack_range = 0.0
attack_speed = 0.0
```

### `res:///data/buildings/GreatHall.tres`
```text
[gd_resource type="Resource" script_class="BuildingData" load_steps=3 format=3 uid="uid://bs1e1mgqnldwq"]
[ext_resource type="Script" uid="uid://js4bbqgeyd6c" path="res://data/buildings/BuildingData.gd" id="1_i2pmy"]
[ext_resource type="PackedScene" uid="uid://cws6xle5x52g4" path="res://scenes/buildings/Base_Building.tscn" id="2_hptna"]
[resource]
script = ExtResource("1_i2pmy")
display_name = "Great Hall"
scene_to_spawn = ExtResource("2_hptna")
build_cost = {
"gold": 100,
"wood": 250
}
grid_size = Vector2i(4, 4)
is_player_buildable = true
is_territory_hub = true
territory_radius = 8
arable_land_capacity = 5
```

### `res:///data/buildings/LumberYard.tres`
```text
[gd_resource type="Resource" script_class="EconomicBuildingData" load_steps=3 format=3 uid="uid://drx4sih8numo1"]
[ext_resource type="Script" uid="uid://d33smw07vm6y4" path="res://data/buildings/EconomicBuildingData.gd" id="1_abcde"]
[ext_resource type="PackedScene" uid="uid://cws6xle5x52g4" path="res://scenes/buildings/Base_Building.tscn" id="2_fghij"]
[resource]
script = ExtResource("1_abcde")
display_name = "Lumber Yard"
scene_to_spawn = ExtResource("2_fghij")
build_cost = {
"wood": 50
}
max_health = 75
grid_size = Vector2i(2, 2)
is_player_buildable = true
territory_radius = 0
```

### `res:///data/buildings/Monastery_Chapel.tres`
```text
[gd_resource type="Resource" script_class="EconomicBuildingData" load_steps=3 format=3 uid="uid://b7p70u4vm3uem"]
[ext_resource type="Script" uid="uid://d33smw07vm6y4" path="res://data/buildings/EconomicBuildingData.gd" id="1_abcde"]
[ext_resource type="PackedScene" uid="uid://cws6xle5x52g4" path="res://scenes/buildings/Base_Building.tscn" id="2_fghij"]
[resource]
script = ExtResource("1_abcde")
resource_type = "gold"
display_name = "Monastery Chapel"
scene_to_spawn = ExtResource("2_fghij")
build_cost = {
"gold": 100,
"stone": 80,
"wood": 40
}
max_health = 120
grid_size = Vector2i(2, 2)
```

### `res:///data/buildings/Monastery_Granary.tres`
```text
[gd_resource type="Resource" script_class="EconomicBuildingData" load_steps=3 format=3 uid="uid://bscr3flprg5ts"]
[ext_resource type="Script" uid="uid://d33smw07vm6y4" path="res://data/buildings/EconomicBuildingData.gd" id="1_abcde"]
[ext_resource type="PackedScene" uid="uid://cws6xle5x52g4" path="res://scenes/buildings/Base_Building.tscn" id="2_fghij"]
[resource]
script = ExtResource("1_abcde")
resource_type = "food"
display_name = "Monastery Granary"
scene_to_spawn = ExtResource("2_fghij")
build_cost = {
"gold": 60,
"stone": 40,
"wood": 100
}
max_health = 90
grid_size = Vector2i(2, 3)
```

### `res:///data/buildings/Monastery_Library.tres`
```text
[gd_resource type="Resource" script_class="EconomicBuildingData" load_steps=3 format=3 uid="uid://bfb0hbf1m2lgf"]
[ext_resource type="Script" uid="uid://d33smw07vm6y4" path="res://data/buildings/EconomicBuildingData.gd" id="1_abcde"]
[ext_resource type="PackedScene" uid="uid://cws6xle5x52g4" path="res://scenes/buildings/Base_Building.tscn" id="2_fghij"]
[resource]
script = ExtResource("1_abcde")
resource_type = "gold"
fixed_payout_amount = 35
storage_cap = 250
display_name = "Monastery Library"
scene_to_spawn = ExtResource("2_fghij")
build_cost = {
"gold": 150,
"stone": 60,
"wood": 80
}
max_health = 80
grid_size = Vector2i(3, 2)
```

### `res:///data/buildings/Monastery_Scriptorium.tres`
```text
[gd_resource type="Resource" script_class="EconomicBuildingData" load_steps=3 format=3 uid="uid://b6dkpjrewc1q6"]
[ext_resource type="Script" uid="uid://d33smw07vm6y4" path="res://data/buildings/EconomicBuildingData.gd" id="1_abcde"]
[ext_resource type="PackedScene" uid="uid://cws6xle5x52g4" path="res://scenes/buildings/Base_Building.tscn" id="2_fghij"]
[resource]
script = ExtResource("1_abcde")
resource_type = "gold"
fixed_payout_amount = 30
storage_cap = 180
display_name = "Monastery Scriptorium"
scene_to_spawn = ExtResource("2_fghij")
build_cost = {
"gold": 120,
"stone": 30,
"wood": 90
}
max_health = 70
grid_size = Vector2i(2, 2)
```

### `res:///data/buildings/Monastery_Watchtower.tres`
```text
[gd_resource type="Resource" script_class="BuildingData" load_steps=5 format=3 uid="uid://ckedcnw210a8k"]
[ext_resource type="Script" uid="uid://js4bbqgeyd6c" path="res://data/buildings/BuildingData.gd" id="1_i2pmy"]
[ext_resource type="PackedScene" uid="uid://cws6xle5x52g4" path="res://scenes/buildings/Base_Building.tscn" id="2_hptna"]
[ext_resource type="PackedScene" uid="uid://de3nko6b1rqyg" path="res://scenes/components/AttackAI.tscn" id="3_ai"]
[ext_resource type="PackedScene" uid="uid://d10havsaesr6i" path="res://scenes/effects/Projectile.tscn" id="4_proj"]
[resource]
script = ExtResource("1_i2pmy")
display_name = "Monastery Watchtower"
scene_to_spawn = ExtResource("2_hptna")
build_cost = {
"gold": 80,
"stone": 120,
"wood": 60
}
max_health = 150
dev_color = Color(0.8, 0.2, 0.2, 1)
is_defensive_structure = true
attack_damage = 10
attack_range = 250.0
ai_component_scene = ExtResource("3_ai")
projectile_scene = ExtResource("4_proj")
projectile_speed = 200.0
```

### `res:///data/buildings/Player_Farm.tres`
```text
[gd_resource type="Resource" script_class="EconomicBuildingData" load_steps=3 format=3 uid="uid://y7xhmemltm28"]
[ext_resource type="PackedScene" uid="uid://cws6xle5x52g4" path="res://scenes/buildings/Base_Building.tscn" id="2_mixjq"]
[ext_resource type="Script" uid="uid://d33smw07vm6y4" path="res://data/buildings/EconomicBuildingData.gd" id="3_svyis"]
[resource]
script = ExtResource("3_svyis")
resource_type = "food"
display_name = "Farm"
scene_to_spawn = ExtResource("2_mixjq")
build_cost = {
"wood": 75
}
max_health = 75
grid_size = Vector2i(2, 2)
dev_color = Color(0.85490197, 0.8, 0.2, 1)
is_player_buildable = true
territory_radius = 0
arable_land_capacity = 5
```

### `res:///data/buildings/generated/Bldg_Naust.tres`
```text
[gd_resource type="Resource" script_class="EconomicBuildingData" load_steps=3 format=3 uid="uid://bwxc10py7rj4c"]
[ext_resource type="PackedScene" uid="uid://cws6xle5x52g4" path="res://scenes/buildings/Base_Building.tscn" id="1_qun0b"]
[ext_resource type="Script" uid="uid://d33smw07vm6y4" path="res://data/buildings/EconomicBuildingData.gd" id="2_p40ji"]
[resource]
script = ExtResource("2_p40ji")
display_name = "Naust"
description = "A shelter for a Longship. Increases Raid Capacity by 1 Ship (3 Squads)."
scene_to_spawn = ExtResource("1_qun0b")
build_cost = {
"gold": 500,
"wood": 250
}
max_health = 150
is_player_buildable = true
construction_effort_required = 150
fleet_capacity_bonus = 3
```

### `res:///data/buildings/generated/Eco_Farm.tres`
```text
[gd_resource type="Resource" script_class="EconomicBuildingData" load_steps=3 format=3 uid="uid://nh6veu8nwt2y"]
[ext_resource type="PackedScene" uid="uid://cws6xle5x52g4" path="res://scenes/buildings/Base_Building.tscn" id="1_a3qf5"]
[ext_resource type="Script" uid="uid://d33smw07vm6y4" path="res://data/buildings/EconomicBuildingData.gd" id="2_dy4o3"]
[resource]
script = ExtResource("2_dy4o3")
display_name = "Farmstead"
description = "A cluster of crops and livestock. Yields FOOD when raided."
scene_to_spawn = ExtResource("1_a3qf5")
build_cost = {
"wood": 50
}
max_health = 50
is_player_buildable = true
construction_effort_required = 50
```

### `res:///data/buildings/generated/Eco_Market.tres`
```text
[gd_resource type="Resource" script_class="EconomicBuildingData" load_steps=3 format=3 uid="uid://po8k2grtnqk3"]
[ext_resource type="PackedScene" uid="uid://cws6xle5x52g4" path="res://scenes/buildings/Base_Building.tscn" id="1_ugvmv"]
[ext_resource type="Script" uid="uid://d33smw07vm6y4" path="res://data/buildings/EconomicBuildingData.gd" id="2_m6nbf"]
[resource]
script = ExtResource("2_m6nbf")
display_name = "Trade Stall"
description = "A merchant's stall. Yields GOLD and GOODS when raided."
scene_to_spawn = ExtResource("1_ugvmv")
build_cost = {
"wood": 100
}
max_health = 80
is_player_buildable = true
construction_effort_required = 80
```

### `res:///data/buildings/generated/Eco_Reliquary.tres`
```text
[gd_resource type="Resource" script_class="EconomicBuildingData" load_steps=3 format=3 uid="uid://d2thv41oy0ta"]
[ext_resource type="PackedScene" uid="uid://cws6xle5x52g4" path="res://scenes/buildings/Base_Building.tscn" id="1_7bmr7"]
[ext_resource type="Script" uid="uid://d33smw07vm6y4" path="res://data/buildings/EconomicBuildingData.gd" id="2_h4xfr"]
[resource]
script = ExtResource("2_h4xfr")
resource_type = "gold"
display_name = "Reliquary"
description = "A holy shrine containing silver and relics. Yields HIGH GOLD."
scene_to_spawn = ExtResource("1_7bmr7")
build_cost = {
"gold": 100,
"stone": 100
}
max_health = 60
is_player_buildable = true
construction_effort_required = 120
```

### `res:///data/buildings/player_economy/Bld_Hof.tres`
```text
[gd_resource type="Resource" script_class="EconomicBuildingData" load_steps=4 format=3 uid="uid://de7upd61q7acb"]
[ext_resource type="PackedScene" uid="uid://cws6xle5x52g4" path="res://scenes/buildings/Base_Building.tscn" id="1_k01sw"]
[ext_resource type="Script" uid="uid://d33smw07vm6y4" path="res://data/buildings/EconomicBuildingData.gd" id="2_nl7oe"]
[ext_resource type="Texture2D" path="res://textures/building_icons/bld_hof_icon.png" id="3_icon"]
[resource]
script = ExtResource("2_nl7oe")
display_name = "Hof"
description = "A sacred wooden structure dedicated to the gods. Generates Piety passively and reduces local civil unrest."
scene_to_spawn = ExtResource("1_k01sw")
icon = ExtResource("3_icon")
build_cost = {
"gold": 50,
"stone": 20,
"wood": 150
}
max_health = 500
is_player_buildable = true
construction_effort_required = 250
```

### `res:///data/buildings/player_economy/Bld_Langhus.tres`
```text
[gd_resource type="Resource" script_class="EconomicBuildingData" load_steps=4 format=3 uid="uid://cqp5ethcro4wy"]
[ext_resource type="PackedScene" uid="uid://cws6xle5x52g4" path="res://scenes/buildings/Base_Building.tscn" id="1_gc777"]
[ext_resource type="Script" uid="uid://d33smw07vm6y4" path="res://data/buildings/EconomicBuildingData.gd" id="2_thncc"]
[ext_resource type="Texture2D" path="res://textures/building_icons/bld_langhus_icon.png" id="3_icon"]
[resource]
script = ExtResource("2_thncc")
display_name = "Langhús"
description = "The fundamental unit of Norse society. A long turf dwelling where extended families live together. Increases max population."
scene_to_spawn = ExtResource("1_gc777")
icon = ExtResource("3_icon")
build_cost = {
"stone": 20,
"wood": 100
}
max_health = 800
is_player_buildable = true
construction_effort_required = 150
```

### `res:///data/buildings/player_economy/Bld_Naust.tres`
```text
[gd_resource type="Resource" script_class="EconomicBuildingData" load_steps=4 format=3 uid="uid://brbkpe7xkott4"]
[ext_resource type="PackedScene" uid="uid://cws6xle5x52g4" path="res://scenes/buildings/Base_Building.tscn" id="1_hcjhq"]
[ext_resource type="Script" uid="uid://d33smw07vm6y4" path="res://data/buildings/EconomicBuildingData.gd" id="2_04eph"]
[ext_resource type="Texture2D" path="res://textures/building_icons/bld_naust_icon.png" id="3_icon"]
[resource]
script = ExtResource("2_04eph")
display_name = "Naust"
description = "A stone-walled slipway for protecting ships. Ships docked here in winter are safe from ice damage and are repaired."
scene_to_spawn = ExtResource("1_hcjhq")
icon = ExtResource("3_icon")
build_cost = {
"stone": 50,
"wood": 200
}
max_health = 1000
is_player_buildable = true
construction_effort_required = 300
```

### `res:///data/buildings/player_economy/Bld_Reykhus.tres`
```text
[gd_resource type="Resource" script_class="EconomicBuildingData" load_steps=4 format=3 uid="uid://couja0jua1f6q"]
[ext_resource type="PackedScene" uid="uid://cws6xle5x52g4" path="res://scenes/buildings/Base_Building.tscn" id="1_17evo"]
[ext_resource type="Script" uid="uid://d33smw07vm6y4" path="res://data/buildings/EconomicBuildingData.gd" id="2_xc2hg"]
[ext_resource type="Texture2D" path="res://textures/building_icons/bld_reykhus_icon.png" id="3_icon"]
[resource]
script = ExtResource("2_xc2hg")
display_name = "Reykhús"
description = "A specialized smokehouse. Converts raw food into non-perishable provisions necessary for long sea voyages."
scene_to_spawn = ExtResource("1_17evo")
icon = ExtResource("3_icon")
build_cost = {
"stone": 40,
"wood": 80
}
max_health = 400
is_player_buildable = true
```

### `res:///data/buildings/player_economy/Bld_Skali.tres`
```text
[gd_resource type="Resource" script_class="EconomicBuildingData" load_steps=4 format=3 uid="uid://c5a1swv6vsqg5"]
[ext_resource type="PackedScene" uid="uid://cws6xle5x52g4" path="res://scenes/buildings/Base_Building.tscn" id="1_cltt7"]
[ext_resource type="Script" uid="uid://d33smw07vm6y4" path="res://data/buildings/EconomicBuildingData.gd" id="2_mqd4q"]
[ext_resource type="Texture2D" path="res://textures/building_icons/bld_skali_icon.png" id="3_icon"]
[resource]
script = ExtResource("2_mqd4q")
display_name = "Skáli"
description = "A grand feasting hall for the Jarl's court. Allows you to maintain a larger retinue of elite warriors through the winter."
scene_to_spawn = ExtResource("1_cltt7")
icon = ExtResource("3_icon")
build_cost = {
"gold": 100,
"stone": 100,
"wood": 400
}
max_health = 2500
is_player_buildable = true
construction_effort_required = 600
```

### `res:///data/buildings/player_economy/Bld_Skemma.tres`
```text
[gd_resource type="Resource" script_class="EconomicBuildingData" load_steps=4 format=3 uid="uid://b2017pygd4lr6"]
[ext_resource type="PackedScene" uid="uid://cws6xle5x52g4" path="res://scenes/buildings/Base_Building.tscn" id="1_dl65s"]
[ext_resource type="Script" uid="uid://d33smw07vm6y4" path="res://data/buildings/EconomicBuildingData.gd" id="2_sk1v1"]
[ext_resource type="Texture2D" path="res://textures/building_icons/bld_skemma_icon.png" id="3_icon"]
[resource]
script = ExtResource("2_sk1v1")
display_name = "Skemma"
description = "A raised timber storehouse used to keep supplies dry. Increases food storage capacity and reduces spoilage during winter."
scene_to_spawn = ExtResource("1_dl65s")
icon = ExtResource("3_icon")
build_cost = {
"wood": 60
}
max_health = 300
is_player_buildable = true
construction_effort_required = 80
```

### `res:///data/buildings/player_economy/Bld_Smidja.tres`
```text
[gd_resource type="Resource" script_class="EconomicBuildingData" load_steps=4 format=3 uid="uid://cj3ex7ealapyy"]
[ext_resource type="PackedScene" uid="uid://cws6xle5x52g4" path="res://scenes/buildings/Base_Building.tscn" id="1_u681b"]
[ext_resource type="Script" uid="uid://d33smw07vm6y4" path="res://data/buildings/EconomicBuildingData.gd" id="2_3i0n5"]
[ext_resource type="Texture2D" path="res://textures/building_icons/bld_smidja_icon.png" id="3_icon"]
[resource]
script = ExtResource("2_3i0n5")
display_name = "Smiðja"
description = "A hot, dark workshop for working bog iron. Unlocks the recruitment of armored Huscarls and weapon upgrades."
scene_to_spawn = ExtResource("1_u681b")
icon = ExtResource("3_icon")
build_cost = {
"stone": 50,
"wood": 120
}
max_health = 600
is_player_buildable = true
construction_effort_required = 200
```

### `res:///data/characters/PlayerJarl.tres`
```text
[gd_resource type="Resource" script_class="JarlData" load_steps=4 format=3]
[ext_resource type="Script" path="res://data/characters/JarlHeirData.gd" id="1_4gouw"]
[ext_resource type="Script" path="res://data/characters/JarlData.gd" id="1_jarl_data"]
[ext_resource type="Script" path="res://data/traits/JarlTraitData.gd" id="3_0bn2j"]
[resource]
script = ExtResource("1_jarl_data")
display_name = "Lagertha"
age = 33
gender = "Female"
renown_tier = 2
current_authority = 7
max_authority = 7
years_since_action = 3
legitimacy = 0
```

### `res:///data/characters/heirs/Ragnar.tres`
```text
[gd_resource type="Resource" format=3 uid="uid://c2ilgcmlp12pb"]
[resource]
```

### `res:///data/characters/heirs/TestHeir.tres`
```text
[gd_resource type="Resource" script_class="JarlHeirData" load_steps=2 format=3 uid="uid://dgxbmto5mqee5"]
[ext_resource type="Script" uid="uid://cql5qpafvywy1" path="res://data/characters/JarlHeirData.gd" id="1_iui4g"]
[resource]
script = ExtResource("1_iui4g")
display_name = "Ragnar (Test)"
```

### `res:///data/events/ambitious_heir.tres`
```text
[gd_resource type="Resource" script_class="EventData" load_steps=5 format=3 uid="uid://ddjwe73h3diq5"]
[ext_resource type="Script" uid="uid://c7lxr02yr1fn6" path="res://data/events/EventData.gd" id="1_event_data"]
[ext_resource type="Script" uid="uid://dvc7gumtvwaal" path="res://data/events/EventChoice.gd" id="2_event_choice"]
[sub_resource type="Resource" id="EventChoice_accept"]
script = ExtResource("2_event_choice")
choice_text = "Here is 100 Renown. Bring us glory!"
tooltip_text = "Spend 100 Renown."
effect_key = "accept"
[sub_resource type="Resource" id="EventChoice_decline"]
script = ExtResource("2_event_choice")
choice_text = "We cannot spare it. Be patient."
tooltip_text = "Your heir will be displeased and gain the 'Rival' trait."
effect_key = "decline"
[resource]
script = ExtResource("1_event_data")
title = "An Ambitious Heir"
description = "Your heir, Ragnar, approaches you. \"My Jarl, I am bored! I wish to lead an expedition to prove my worth. Please fund it so I may bring...
event_id = "ambitious_heir_1"
base_chance = 1.0
must_have_trait = "Ambitious"
min_available_heirs = 1
choices = Array[ExtResource("2_event_choice")]([SubResource("EventChoice_accept"), SubResource("EventChoice_decline")])
```

### `res:///data/legacy/JellingStone.tres`
```text
[gd_resource type="Resource" script_class="LegacyUpgradeData" load_steps=2 format=3]
[ext_resource type="Script" path="res://data/legacy/LegacyUpgradeData.gd" id="1_jelling"]
[resource]
script = ExtResource("1_jelling")
display_name = "Erect Jelling Stone"
description = "Commission a great rune stone to proclaim your dynasty's glory. All future heirs will begin their rule with bonus Renown."
renown_cost = 200
authority_cost = 2
effect_key = "UPG_JELLING_STONE"
prerequisite_key = ""
```

### `res:///data/legacy/TrainingGrounds.tres`
```text
[gd_resource type="Resource" script_class="LegacyUpgradeData" load_steps=2 format=3 uid="uid://ckxjlif8kchlu"]
[ext_resource type="Script" uid="uid://bot3rirdcml6f" path="res://data/legacy/LegacyUpgradeData.gd" id="1_et52o"]
[resource]
script = ExtResource("1_et52o")
display_name = "Training Regime"
description = "New recruits start with extensive drill (level 3)"
renown_cost = 500
authority_cost = 3
effect_key = "UPG_TRAINING_GROUNDS"
```

### `res:///data/legacy/TrelleborgFortress.tres`
```text
[gd_resource type="Resource" script_class="LegacyUpgradeData" load_steps=2 format=3]
[ext_resource type="Script" path="res://data/legacy/LegacyUpgradeData.gd" id="1_trelleborg"]
[resource]
script = ExtResource("1_trelleborg")
display_name = "Upgrade Trelleborg"
description = "Invest in the Trelleborg's defenses, permanently increasing the max garrison size for your home settlement."
renown_cost = 100
authority_cost = 3
effect_key = "UPG_TRELLEBORG"
prerequisite_key = ""
```

### `res:///data/legacy/Upg_BuildChapel.tres`
```text
[gd_resource type="Resource" script_class="LegacyUpgradeData" load_steps=2 format=3 uid="uid://c4qpn4hvsgkvh"]
[ext_resource type="Script" uid="uid://bot3rirdcml6f" path="res://data/legacy/LegacyUpgradeData.gd" id="1_chapel"]
[resource]
script = ExtResource("1_chapel")
display_name = "Build Chapel"
description = "Erect a small chapel, honoring the gods and securing their favor for your dynasty."
renown_cost = 50
effect_key = "UPG_BUILD_CHAPEL"
```

### `res:///data/legacy/VikingLongships.tres`
```text
[gd_resource type="Resource" script_class="LegacyUpgradeData" load_steps=2 format=3]
[ext_resource type="Script" path="res://data/legacy/LegacyUpgradeData.gd" id="1_longships"]
[resource]
script = ExtResource("1_longships")
display_name = "Viking Longships"
description = "Improve shipbuilding techniques, allowing for faster raids and more loot."
renown_cost = 150
authority_cost = 1
effect_key = "UPG_LONGSHIPS"
prerequisite_key = ""
```

### `res:///data/resources/Card_Focus_Raid.tres`
```text
[gd_resource type="Resource" script_class="SeasonalCardResource" load_steps=2 format=3 uid="uid://du2gsa2xinlrm"]
[ext_resource type="Script" uid="uid://cni5gdnpbb1v2" path="res://data/resources/SeasonalCardResource.gd" id="1_r2a8h"]
[resource]
script = ExtResource("1_r2a8h")
title = "Viking Focus"
description = "Boost Authority for multiple raids. Increases amount of time needed to complete buildings"
```

### `res:///data/resources/Card_Spring_Expansion.tres`
```text
[gd_resource type="Resource" script_class="SeasonalCardResource" load_steps=2 format=3 uid="uid://dt38bx8jkvrno"]
[ext_resource type="Script" uid="uid://cni5gdnpbb1v2" path="res://data/resources/SeasonalCardResource.gd" id="1_sbleo"]
[resource]
script = ExtResource("1_sbleo")
title = "Construction Focus"
description = "Boosts building construction time. Decreases authority for raids."
```

### `res:///data/settlements/economic_base.tres`
```text
[gd_resource type="Resource" script_class="SettlementData" load_steps=2 format=3 uid="uid://chtd3i4qtdv31"]
[ext_resource type="Script" uid="uid://hlb8s5g0yp6k" path="res://data/settlements/SettlementData.gd" id="1_e06fl"]
[resource]
script = ExtResource("1_e06fl")
treasury = {
"food": 200,
"gold": 1000,
"stone": 300,
"wood": 500
}
placed_buildings = Array[Dictionary]([{
"grid_position": Vector2i(10, 8),
"resource_path": "res://data/buildings/GreatHall.tres"
}, {
"grid_position": Vector2i(6, 6),
"resource_path": "res://data/buildings/LumberYard.tres"
}, {
"grid_position": Vector2i(8, 6),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(12, 6),
"resource_path": "res://data/buildings/LumberYard.tres"
}, {
"grid_position": Vector2i(14, 6),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(8, 4),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(10, 4),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(12, 4),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(10, 3),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}])
garrisoned_units = {
"res://data/units/Unit_PlayerRaider.tres": 3
}
```

### `res:///data/settlements/fortress_layout.tres`
```text
[gd_resource type="Resource" script_class="SettlementData" load_steps=2 format=3 uid="uid://c2nrib7nroeas"]
[ext_resource type="Script" uid="uid://hlb8s5g0yp6k" path="res://data/settlements/SettlementData.gd" id="1_settlement_data"]
[resource]
script = ExtResource("1_settlement_data")
treasury = {
"food": 150,
"gold": 1200,
"stone": 500,
"wood": 600
}
placed_buildings = Array[Dictionary]([{
"grid_position": Vector2i(10, 10),
"resource_path": "res://data/buildings/GreatHall.tres"
}, {
"grid_position": Vector2i(6, 6),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(7, 6),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(8, 6),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(12, 6),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(13, 6),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(14, 6),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(6, 14),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(7, 14),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(13, 14),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(14, 14),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(5, 5),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(15, 5),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(5, 15),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(15, 15),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}])
garrisoned_units = {
"res://data/units/Unit_PlayerRaider.tres": 8
}
```

### `res:///data/settlements/generated/raid_rich_hub_01.tres`
```text
[gd_resource type="Resource" script_class="SettlementData" load_steps=3 format=3 uid="uid://dar76dyrtu8ts"]
[ext_resource type="Script" uid="uid://hlb8s5g0yp6k" path="res://data/settlements/SettlementData.gd" id="1_0cqgt"]
[ext_resource type="Script" uid="uid://koj0vo5eoaum" path="res://data/units/WarbandData.gd" id="2_afm35"]
[resource]
script = ExtResource("1_0cqgt")
treasury = {
"food": 800,
"gold": 2000,
"stone": 500,
"wood": 1000
}
placed_buildings = Array[Dictionary]([{
"grid_position": Vector2i(56, 25),
"resource_path": "res://data/buildings/GreatHall.tres"
}, {
"grid_position": Vector2i(47, 21),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(47, 22),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(47, 28),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(47, 29),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(48, 19),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(48, 20),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(48, 21),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(48, 22),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(48, 28),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(48, 29),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(48, 30),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(48, 31),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(49, 18),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(49, 19),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(49, 20),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(49, 30),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(49, 31),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(49, 32),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(50, 17),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(50, 18),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(50, 32),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(50, 33),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(51, 17),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(51, 18),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(51, 32),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(51, 33),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(52, 16),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(52, 17),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(52, 33),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(52, 34),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(53, 16),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(53, 17),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(53, 33),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(53, 34),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(54, 16),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(54, 34),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(55, 16),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(55, 34),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(56, 15),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(56, 16),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(56, 34),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(56, 35),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(57, 16),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(57, 34),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(58, 16),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(58, 34),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(59, 16),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(59, 17),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(59, 33),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(59, 34),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(60, 16),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(60, 17),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(60, 33),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(60, 34),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(61, 17),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(61, 18),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(61, 32),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(61, 33),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(62, 17),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(62, 18),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(62, 32),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(62, 33),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(63, 18),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(63, 19),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(63, 20),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(63, 30),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(63, 31),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(63, 32),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(64, 19),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(64, 20),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(64, 21),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(64, 22),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(64, 28),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(64, 29),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(64, 30),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(64, 31),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(65, 21),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(65, 22),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(65, 23),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(65, 24),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(65, 25),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(65, 26),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(65, 27),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(65, 28),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(65, 29),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(66, 25),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(62, 27),
"resource_path": "res://data/buildings/Monastery_Scriptorium.tres"
}, {
"grid_position": Vector2i(61, 21),
"resource_path": "res://data/buildings/Monastery_Scriptorium.tres"
}, {
"grid_position": Vector2i(50, 26),
"resource_path": "res://data/buildings/Monastery_Library.tres"
}, {
"grid_position": Vector2i(53, 20),
"resource_path": "res://data/buildings/Monastery_Scriptorium.tres"
}, {
"grid_position": Vector2i(56, 32),
"resource_path": "res://data/buildings/Monastery_Library.tres"
}, {
"grid_position": Vector2i(56, 18),
"resource_path": "res://data/buildings/Monastery_Library.tres"
}, {
"grid_position": Vector2i(62, 25),
"resource_path": "res://data/buildings/Monastery_Library.tres"
}, {
"grid_position": Vector2i(50, 21),
"resource_path": "res://data/buildings/Monastery_Library.tres"
}, {
"grid_position": Vector2i(62, 23),
"resource_path": "res://data/buildings/Monastery_Library.tres"
}, {
"grid_position": Vector2i(53, 31),
"resource_path": "res://data/buildings/Monastery_Library.tres"
}, {
"grid_position": Vector2i(39, 26),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(42, 28),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(43, 32),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(43, 35),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(46, 10),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(48, 8),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(48, 40),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(49, 35),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(50, 7),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(50, 13),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(50, 40),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(51, 44),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(55, 37),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(56, 10),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(56, 42),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(58, 6),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(59, 12),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(61, 36),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(63, 40),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(64, 34),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(66, 32),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(66, 37),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(68, 12),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(68, 16),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(68, 33),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(70, 11),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(71, 37),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(72, 26),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(73, 17),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(73, 20),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(73, 31),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(23, 31),
"resource_path": "res://data/buildings/Player_Farm.tres"
}, {
"grid_position": Vector2i(27, 43),
"resource_path": "res://data/buildings/LumberYard.tres"
}, {
"grid_position": Vector2i(28, 27),
"resource_path": "res://data/buildings/Player_Farm.tres"
}, {
"grid_position": Vector2i(30, 9),
"resource_path": "res://data/buildings/LumberYard.tres"
}, {
"grid_position": Vector2i(31, 24),
"resource_path": "res://data/buildings/Player_Farm.tres"
}, {
"grid_position": Vector2i(34, 23),
"resource_path": "res://data/buildings/LumberYard.tres"
}, {
"grid_position": Vector2i(37, 39),
"resource_path": "res://data/buildings/Player_Farm.tres"
}, {
"grid_position": Vector2i(38, 5),
"resource_path": "res://data/buildings/Player_Farm.tres"
}, {
"grid_position": Vector2i(38, 42),
"resource_path": "res://data/buildings/LumberYard.tres"
}, {
"grid_position": Vector2i(38, 44),
"resource_path": "res://data/buildings/LumberYard.tres"
}, {
"grid_position": Vector2i(39, 2),
"resource_path": "res://data/buildings/Player_Farm.tres"
}, {
"grid_position": Vector2i(40, 4),
"resource_path": "res://data/buildings/Player_Farm.tres"
}, {
"grid_position": Vector2i(42, 2),
"resource_path": "res://data/buildings/Player_Farm.tres"
}, {
"grid_position": Vector2i(48, 1),
"resource_path": "res://data/buildings/LumberYard.tres"
}, {
"grid_position": Vector2i(48, 47),
"resource_path": "res://data/buildings/LumberYard.tres"
}, {
"grid_position": Vector2i(56, 2),
"resource_path": "res://data/buildings/LumberYard.tres"
}, {
"grid_position": Vector2i(60, 2),
"resource_path": "res://data/buildings/Player_Farm.tres"
}, {
"grid_position": Vector2i(61, 47),
"resource_path": "res://data/buildings/LumberYard.tres"
}, {
"grid_position": Vector2i(66, 4),
"resource_path": "res://data/buildings/LumberYard.tres"
}, {
"grid_position": Vector2i(70, 44),
"resource_path": "res://data/buildings/Player_Farm.tres"
}, {
"grid_position": Vector2i(72, 1),
"resource_path": "res://data/buildings/LumberYard.tres"
}, {
"grid_position": Vector2i(72, 9),
"resource_path": "res://data/buildings/Player_Farm.tres"
}, {
"grid_position": Vector2i(74, 47),
"resource_path": "res://data/buildings/Player_Farm.tres"
}, {
"grid_position": Vector2i(76, 1),
"resource_path": "res://data/buildings/LumberYard.tres"
}, {
"grid_position": Vector2i(76, 11),
"resource_path": "res://data/buildings/Player_Farm.tres"
}, {
"grid_position": Vector2i(77, 8),
"resource_path": "res://data/buildings/LumberYard.tres"
}, {
"grid_position": Vector2i(77, 46),
"resource_path": "res://data/buildings/Player_Farm.tres"
}])
```

### `res:///data/settlements/home_base_fixed.tres`
```text
[gd_resource type="Resource" script_class="SettlementData" load_steps=2 format=3 uid="uid://dsgbqyqqlvlwn"]
[ext_resource type="Script" uid="uid://hlb8s5g0yp6k" path="res://data/settlements/SettlementData.gd" id="1_settlement_data"]
[resource]
script = ExtResource("1_settlement_data")
treasury = {
"food": 657,
"gold": 600,
"stone": 125,
"wood": 1547
}
placed_buildings = Array[Dictionary]([{
"grid_position": Vector2i(33, 18),
"resource_path": "res://data/buildings/LumberYard.tres"
}, {
"grid_position": Vector2i(31, 18),
"resource_path": "res://data/buildings/LumberYard.tres"
}, {
"grid_position": Vector2i(29, 18),
"resource_path": "res://data/buildings/LumberYard.tres"
}, {
"grid_position": Vector2i(31, 16),
"resource_path": "res://data/buildings/LumberYard.tres"
}, {
"grid_position": Vector2(36, 13),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2(37, 13),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2(38, 13),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(42, 15),
"resource_path": "res://data/buildings/LumberYard.tres"
}, {
"grid_position": Vector2i(41, 9),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(52, 11),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(40, 9),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(51, 11),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(50, 11),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(49, 11),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(32, 9),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(48, 16),
"resource_path": "res://data/buildings/LumberYard.tres"
}])
pending_construction_buildings = [{
"grid_position": Vector2i(43, 11),
"progress": 25,
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(36, 26),
"progress": 0,
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}]
garrisoned_units = {
"res://data/units/Unit_PlayerRaider.tres": 16
}
worker_assignments = {
"construction": 1,
"food": 0,
"stone": 0,
"wood": 0
}
```

### `res:///data/settlements/monastery_base.tres`
```text
[gd_resource type="Resource" script_class="SettlementData" load_steps=2 format=3 uid="uid://okf2novkg804"]
[ext_resource type="Script" uid="uid://hlb8s5g0yp6k" path="res://data/settlements/SettlementData.gd" id="1_pnvr3"]
[resource]
script = ExtResource("1_pnvr3")
treasury = {
"food": 200,
"gold": 1000,
"stone": 300,
"wood": 500
}
placed_buildings = Array[Dictionary]([{
"grid_position": Vector2i(10, 10),
"resource_path": "res://data/buildings/GreatHall.tres"
}, {
"grid_position": Vector2i(8, 7),
"resource_path": "res://data/buildings/Monastery_Chapel.tres"
}, {
"grid_position": Vector2i(12, 7),
"resource_path": "res://data/buildings/Monastery_Library.tres"
}, {
"grid_position": Vector2i(8, 13),
"resource_path": "res://data/buildings/Monastery_Scriptorium.tres"
}, {
"grid_position": Vector2i(12, 13),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(6, 5),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(8, 5),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(12, 5),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(14, 5),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(5, 4),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(15, 4),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(5, 15),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(15, 15),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}])
garrisoned_units = {
"res://data/units/Unit_PlayerRaider.tres": 3
}
```

### `res:///data/settlements/monastery_layout.tres`
```text
[gd_resource type="Resource" script_class="SettlementData" load_steps=2 format=3 uid="uid://6kk36f5nlwns"]
[ext_resource type="Script" uid="uid://hlb8s5g0yp6k" path="res://data/settlements/SettlementData.gd" id="1_settlement_data"]
[resource]
script = ExtResource("1_settlement_data")
treasury = {
"food": 300,
"gold": 800,
"stone": 200,
"wood": 400
}
placed_buildings = Array[Dictionary]([{
"grid_position": Vector2i(10, 10),
"resource_path": "res://data/buildings/GreatHall.tres"
}, {
"grid_position": Vector2i(8, 7),
"resource_path": "res://data/buildings/Monastery_Chapel.tres"
}, {
"grid_position": Vector2i(12, 7),
"resource_path": "res://data/buildings/Monastery_Library.tres"
}, {
"grid_position": Vector2i(8, 13),
"resource_path": "res://data/buildings/Monastery_Scriptorium.tres"
}, {
"grid_position": Vector2i(12, 13),
"resource_path": "res://data/buildings/Monastery_Granary.tres"
}, {
"grid_position": Vector2i(6, 5),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(14, 5),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(5, 4),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(15, 4),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}])
garrisoned_units = {
"res://data/units/Unit_PlayerRaider.tres": 3
}
```

### `res:///data/settlements/sample_fortress_gui.tres`
```text
[gd_resource type="SettlementData" script_class="SettlementData" load_steps=2 format=3 uid="uid://cl3pbg7tiqyng"]
[ext_resource type="Script" uid="uid://hlb8s5g0yp6k" path="res://data/settlements/SettlementData.gd" id="1"]
[resource]
resource_local_to_scene = false
resource_name = ""
script = ExtResource("1")
treasury = {
"food": 300,
"gold": 1000,
"stone": 400,
"wood": 500
}
placed_buildings = Array[Dictionary]([{
"grid_position": Vector2i(30, 20),
"resource_path": "res://data/buildings/GreatHall.tres"
}, {
"grid_position": Vector2i(29, 19),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(30, 19),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(31, 19),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(29, 21),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(30, 21),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(31, 21),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(28, 18),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(32, 18),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(28, 22),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(32, 22),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(27, 20),
"resource_path": "res://data/buildings/LumberYard.tres"
}, {
"grid_position": Vector2i(33, 20),
"resource_path": "res://data/buildings/LumberYard.tres"
}])
garrisoned_units = {
"res://data/units/Unit_PlayerRaider.tres": 4,
"res://data/units/Unit_Raider.tres": 8
}
```

### `res:///data/settlements/small_defensive.tres`
```text
[gd_resource type="Resource" script_class="SettlementData" load_steps=2 format=3 uid="uid://c5wkbqulshkqe"]
[ext_resource type="Script" uid="uid://hlb8s5g0yp6k" path="res://data/settlements/SettlementData.gd" id="1_mtb34"]
[resource]
script = ExtResource("1_mtb34")
treasury = {
"food": 200,
"gold": 1000,
"stone": 300,
"wood": 500
}
placed_buildings = Array[Dictionary]([{
"grid_position": Vector2i(8, 6),
"resource_path": "res://data/buildings/GreatHall.tres"
}, {
"grid_position": Vector2i(5, 4),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(6, 4),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(7, 4),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(11, 4),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(12, 4),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(13, 4),
"resource_path": "res://data/buildings/Bldg_Wall.tres"
}, {
"grid_position": Vector2i(4, 3),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(14, 3),
"resource_path": "res://data/buildings/Monastery_Watchtower.tres"
}, {
"grid_position": Vector2i(6, 8),
"resource_path": "res://data/buildings/LumberYard.tres"
}])
garrisoned_units = {
"res://data/units/Unit_PlayerRaider.tres": 3
}
```

### `res:///data/traits/Trait_Ambitious.tres`
```text
[gd_resource type="Resource" script_class="JarlTraitData" load_steps=2 format=3 uid="uid://wo43cpcxhf4i"]
[ext_resource type="Script" uid="uid://dwh8olikns4xw" path="res://data/traits/JarlTraitData.gd" id="1_jarl_trait"]
[resource]
script = ExtResource("1_jarl_trait")
display_name = "Ambitious"
description = "This Jarl is driven by a burning desire for power and glory, and inspires the same in their children."
command_modifier = 2
stewardship_modifier = -1
intrigue_modifier = 1
```

### `res:///data/traits/Trait_Cowardly.tres`
```text
[gd_resource type="Resource" script_class="JarlTraitData" load_steps=2 format=3 uid="uid://bivw1rejl06qi"]
[ext_resource type="Script" path="res://data/traits/JarlTraitData.gd" id="1_jarl_trait"]
[resource]
script = ExtResource("1_jarl_trait")
resource_local_to_scene = false
resource_name = ""
display_name = "Cowardly"
description = "This character has shown cowardice in battle, losing the respect of their people."
is_visible = true
command_modifier = -3
stewardship_modifier = 0
intrigue_modifier = 0
renown_per_year_modifier = -2.0
vassal_opinion_modifier = -10
alliance_cost_modifier = 1.2
is_wounded_trait = false
is_dishonorable_trait = true
```

### `res:///data/traits/Trait_Legendary.tres`
```text
[gd_resource type="Resource" script_class="JarlTraitData" load_steps=2 format=3 uid="uid://c6a8qce5fgub0"]
[ext_resource type="Script" path="res://data/traits/JarlTraitData.gd" id="1_jarl_trait"]
[resource]
script = ExtResource("1_jarl_trait")
resource_local_to_scene = false
resource_name = ""
display_name = "Legendary"
description = "This character has achieved legendary status through glorious deeds and successful raids."
is_visible = true
command_modifier = 5
stewardship_modifier = 2
intrigue_modifier = 3
renown_per_year_modifier = 5.0
vassal_opinion_modifier = 20
alliance_cost_modifier = 0.8
is_wounded_trait = false
is_dishonorable_trait = false
```

### `res:///data/traits/Trait_Maimed.tres`
```text
[gd_resource type="Resource" script_class="JarlTraitData" load_steps=2 format=3 uid="uid://bbiwlkmmne5md"]
[ext_resource type="Script" path="res://data/traits/JarlTraitData.gd" id="1_jarl_trait"]
[resource]
script = ExtResource("1_jarl_trait")
resource_local_to_scene = false
resource_name = ""
display_name = "Maimed"
description = "This character has suffered a permanent injury that affects their combat ability."
is_visible = true
command_modifier = -2
stewardship_modifier = 0
intrigue_modifier = 0
renown_per_year_modifier = -1.0
vassal_opinion_modifier = -5
alliance_cost_modifier = 1.1
is_wounded_trait = true
is_dishonorable_trait = false
```

### `res:///data/traits/Trait_Pious.tres`
```text
[gd_resource type="Resource" script_class="JarlTraitData" load_steps=2 format=3 uid="uid://y1xcw7hwydkx"]
[ext_resource type="Script" uid="uid://dwh8olikns4xw" path="res://data/traits/JarlTraitData.gd" id="1_jarl_trait"]
[resource]
script = ExtResource("1_jarl_trait")
display_name = "Pious"
description = "This Jarl is known for their devotion to the gods, making religious acts cheaper and sacrilege more costly."
stewardship_modifier = 1
```

### `res:///data/traits/Trait_Rival.tres`
```text
[gd_resource type="Resource" script_class="JarlTraitData" load_steps=2 format=3]
[ext_resource type="Script" path="res://data/traits/JarlTraitData.gd" id="1_jarl_trait"]
[resource]
script = ExtResource("1_jarl_trait")
display_name = "Rival"
description = "This character has developed a bitter rivalry with their liege."
is_visible = true
command_modifier = 1
stewardship_modifier = 0
intrigue_modifier = 2
vassal_opinion_modifier = -15
```

### `res:///data/traits/Trait_Seasoned.tres`
```text
[gd_resource type="Resource" script_class="JarlTraitData" load_steps=2 format=3 uid="uid://bvgxc8k7j2rqp"]
[ext_resource type="Script" uid="uid://dwh8olikns4xw" path="res://data/traits/JarlTraitData.gd" id="1_jarl_trait"]
[resource]
script = ExtResource("1_jarl_trait")
display_name = "Seasoned"
description = "This character has experience from successful expeditions, granting improved combat and leadership abilities."
command_modifier = 2
stewardship_modifier = 1
```

### `res:///data/units/EnemyVikingRaider_Data.tres`
```text
[gd_resource type="Resource" script_class="UnitData" load_steps=5 format=3 uid="uid://brnbvjwnoyh3j"]
[ext_resource type="PackedScene" uid="uid://de3nko6b1rqyg" path="res://scenes/components/AttackAI.tscn" id="1_4g7rt"]
[ext_resource type="Script" uid="uid://cq155t20ujb2j" path="res://data/units/UnitData.gd" id="1_script"]
[ext_resource type="Texture2D" uid="uid://pwi4bv5ch827" path="res://textures/placeholders/unit_placeholder.png" id="3_6go6j"]
[ext_resource type="Texture2D" uid="uid://buwxqfjw7whon" path="res://textures/units/viking_raider_sprite.png" id="6_lv2v5"]
[resource]
script = ExtResource("1_script")
display_name = "Viking Raider"
scene_path = "uid://btlcifwc6ckux"
icon = ExtResource("3_6go6j")
spawn_cost = {
"food": 30,
"gold": 15
}
max_health = 45
move_speed = 100.0
attack_damage = 10
attack_range = 200.0
attack_speed = 0.5
visual_texture = ExtResource("6_lv2v5")
ai_component_scene = ExtResource("1_4g7rt")
```

### `res:///data/units/Unit_Bondi.tres`
```text
[gd_resource type="Resource" script_class="UnitData" load_steps=5 format=3 uid="uid://dpe2acwvvxthl"]
[ext_resource type="PackedScene" uid="uid://de3nko6b1rqyg" path="res://scenes/components/AttackAI.tscn" id="1_xgb1t"]
[ext_resource type="Texture2D" uid="uid://bqewu3c53xrvk" path="res://art/units/bondi_32x32.png" id="1_xjqxg"]
[ext_resource type="Texture2D" uid="uid://v1mpf4cy67hf" path="res://ui/assets/wax_seal.png" id="2_xgb1t"]
[ext_resource type="Script" uid="uid://cq155t20ujb2j" path="res://data/units/UnitData.gd" id="2_xjqxg"]
[resource]
script = ExtResource("2_xjqxg")
display_name = "Bondi"
scene_path = "res://scenes/units/Bondi.tscn"
icon = ExtResource("2_xgb1t")
spawn_cost = {
"food": 0
}
max_health = 40
attack_damage = 15
attack_range = 30.0
visual_texture = ExtResource("1_xjqxg")
ai_component_scene = ExtResource("1_xgb1t")
```

### `res:///data/units/Unit_Civilian.tres`
```text
[gd_resource type="Resource" script_class="UnitData" load_steps=3 format=3 uid="uid://iiho31ik0qvb"]
[ext_resource type="Script" uid="uid://cq155t20ujb2j" path="res://data/units/UnitData.gd" id="1_4oj7p"]
[ext_resource type="Texture2D" uid="uid://bf5iebrbljx12" path="res://art/units/Villager_Norse_Male_Libre.png" id="1_ca617"]
[resource]
script = ExtResource("1_4oj7p")
display_name = "Villager"
scene_path = "uid://c7powse34uuxc"
icon = ExtResource("1_ca617")
max_health = 20
move_speed = 120.0
attack_damage = 0
attack_range = 0.0
visual_texture = ExtResource("1_ca617")
target_pixel_size = Vector2(24, 24)
```

### `res:///data/units/Unit_Drengr.tres`
```text
[gd_resource type="Resource" script_class="UnitData" load_steps=5 format=3 uid="uid://cg3bi0swsm6k4"]
[ext_resource type="Texture2D" uid="uid://buwxqfjw7whon" path="res://textures/units/viking_raider_sprite.png" id="1_15vom"]
[ext_resource type="PackedScene" uid="uid://de3nko6b1rqyg" path="res://scenes/components/AttackAI.tscn" id="1_ty6b3"]
[ext_resource type="Texture2D" uid="uid://v1mpf4cy67hf" path="res://ui/assets/wax_seal.png" id="2_fuc7h"]
[ext_resource type="Script" uid="uid://cq155t20ujb2j" path="res://data/units/UnitData.gd" id="2_ty6b3"]
[resource]
script = ExtResource("2_ty6b3")
display_name = "Drengr"
scene_path = "res://scenes/units/Drengr.tscn"
icon = ExtResource("2_fuc7h")
spawn_cost = {
"food": 0
}
max_health = 45
move_speed = 85.0
attack_damage = 12
attack_speed = 1.4
visual_texture = ExtResource("1_15vom")
ai_component_scene = ExtResource("1_ty6b3")
wergild_cost = 150
```

### `res:///data/units/Unit_PlayerRaider.tres`
```text
[gd_resource type="Resource" script_class="UnitData" load_steps=4 format=3 uid="uid://ejxn3hg8xcu6"]
[ext_resource type="Script" uid="uid://cq155t20ujb2j" path="res://data/units/UnitData.gd" id="1_script"]
[ext_resource type="Texture2D" uid="uid://buwxqfjw7whon" path="res://textures/units/viking_raider_sprite.png" id="3_viking_sprite"]
[ext_resource type="PackedScene" uid="uid://de3nko6b1rqyg" path="res://scenes/components/AttackAI.tscn" id="4_ai"]
[resource]
script = ExtResource("1_script")
display_name = "Viking Raider"
scene_path = "uid://cfanwutbtfcp2"
icon = ExtResource("3_viking_sprite")
spawn_cost = {
"food": 25,
"gold": 10
}
max_health = 60
move_speed = 100.0
attack_damage = 15
attack_range = 80.0
attack_speed = 0.6000000000058208
visual_texture = ExtResource("3_viking_sprite")
acceleration = 12.0
linear_damping = 6.0
ai_component_scene = ExtResource("4_ai")
projectile_speed = 399.6600000000035
```

### `res:///data/units/Unit_Thrall.tres`
```text
[gd_resource type="Resource" script_class="UnitData" load_steps=4 format=3 uid="uid://dtgp7yi7grl6g"]
[ext_resource type="PackedScene" uid="uid://de3nko6b1rqyg" path="res://scenes/components/AttackAI.tscn" id="1_ji81e"]
[ext_resource type="Texture2D" uid="uid://ignmy4ooj1v1" path="res://art/units/Thrall_Male_Libre.png" id="2_4x1q2"]
[ext_resource type="Script" uid="uid://cq155t20ujb2j" path="res://data/units/UnitData.gd" id="3_tk336"]
[resource]
script = ExtResource("3_tk336")
display_name = "Thrall"
scene_path = "uid://c4id53apf1ynt"
icon = ExtResource("2_4x1q2")
max_health = 30
move_speed = 60.0
attack_damage = 0
max_loot_capacity = 300
encumbrance_speed_penalty = 0.3
visual_texture = ExtResource("2_4x1q2")
pillage_speed = 15
burn_renown = 0
ai_component_scene = ExtResource("1_ji81e")
wergild_cost = 15
```

### `res:///data/world_map/Region_Agdir.tres`
```text
[gd_resource type="Resource" script_class="WorldRegionData" load_steps=2 format=3 uid="uid://rb575376gmgd"]
[ext_resource type="Script" uid="uid://dqlbgeegli821" path="res://data/world_map/WorldRegionData.gd" id="1_8hjpx"]
[resource]
script = ExtResource("1_8hjpx")
```

### `res:///data/world_map/Region_Monastery.tres`
```text
[gd_resource type="Resource" script_class="WorldRegionData" load_steps=3 format=3 uid="uid://bk6wv22mknptc"]
[ext_resource type="Resource" uid="uid://okf2novkg804" path="res://data/settlements/monastery_base.tres" id="1_settlement"]
[ext_resource type="Script" uid="uid://dqlbgeegli821" path="res://data/world_map/WorldRegionData.gd" id="2_world_region"]
[resource]
script = ExtResource("2_world_region")
display_name = "Nearby Monastery"
description = "A wealthy but poorly-defended monastery. An easy target for a quick grab."
target_settlement_data = ExtResource("1_settlement")
region_type_tag = "Monastery"
yearly_income = {
"food": 10,
"gold": 25
}
```

### `res:///resources/rectangleshape2d_879319.tres`
```text
[gd_resource type="RectangleShape2D" format=3 uid="uid://bvjkr2ny3hnvo"]
[resource]
size = Vector2(25, 3)
```

### `res:///resources/separation_circle_shape.tres`
```text
[gd_resource type="CircleShape2D" format=3 uid="uid://bda7xb0judu2h"]
[resource]
radius = 40.0
```

### `res:///textures/placeholders/building_placeholder.tres`
```text
[gd_resource type="PlaceholderTexture2D" format=3 uid="uid://ds2w780g4nf1t"]
[resource]
size = Vector2(128, 128)
```

### `res:///textures/placeholders/defensive_placeholder.tres`
```text
[gd_resource type="PlaceholderTexture2D" format=3 uid="uid://db3pfgf4u4pql"]
[resource]
size = Vector2(96, 96)
```

### `res:///textures/placeholders/unit_placeholder.tres`
```text
[gd_resource type="PlaceholderTexture2D" format=3 uid="uid://bg2e08mncpjg1"]
[resource]
size = Vector2(64, 64)
```

### `res:///textures/placeholders/unit_texture.tres`
```text
[gd_resource type="PlaceholderTexture2D" format=3 uid="uid://cybqs3wt5wpg3"]
[resource]
size = Vector2(10, 2)
```

## 🔗 DEPENDENCY GRAPH
- `res:///addons/GodotAiSuite/godot_ai_suite.gd`
  - depends on: `res://addons/GodotAiSuite/prompt_library/prompt_library.tscn`
  - depends on: `res://addons/GodotAiSuite/assets/prompt_library_icon.png`
- `res:///addons/gut/cli/change_project_warnings.gd`
  - depends on: `res://addons/gut/cli/optparse.gd`
  - depends on: `res://addons/gut/warnings_manager.gd`
- `res:///addons/gut/cli/gut_cli.gd`
  - depends on: `res://addons/gut/cli/optparse.gd`
  - depends on: `res://addons/gut/gut.gd`
  - depends on: `res://addons/gut/gui/GutRunner.tscn`
  - depends on: `res://addons/gut/gut_config.gd`
- `res:///addons/gut/diff_tool.gd`
  - depends on: `res://addons/gut/diff_formatter.gd`
- `res:///addons/gut/gui/GutBottomPanel.gd`
  - depends on: `res://addons/gut/gui/editor_globals.gd`
  - depends on: `res://addons/gut/gui/gut_config_gui.gd`
  - depends on: `res://addons/gut/gui/about.tscn`
  - depends on: `res://addons/gut/gut_config.gd`
  - depends on: `res://addons/gut/images/HSplitContainer.svg`
- `res:///addons/gut/gui/GutControl.gd`
  - depends on: `res://addons/gut/gut_config.gd`
  - depends on: `res://addons/gut/gui/GutRunner.tscn`
  - depends on: `res://addons/gut/gui/gut_config_gui.gd`
  - depends on: `res://addons/gut/images/Script.svg`
  - depends on: `res://addons/gut/images/Folder.svg`
- `res:///addons/gut/gui/GutEditorWindow.gd`
  - depends on: `res://addons/gut/gui/editor_globals.gd`
- `res:///addons/gut/gui/GutRunner.gd`
  - depends on: `res://addons/gut/gut.gd`
  - depends on: `res://addons/gut/result_exporter.gd`
  - depends on: `res://addons/gut/gut_config.gd`
  - depends on: `res://addons/gut/gui/editor_globals.gd`
- `res:///addons/gut/gui/OutputText.gd`
  - depends on: `res://addons/gut/gui/editor_globals.gd`
  - depends on: `res://addons/gut/gui/panel_controls.gd`
- `res:///addons/gut/gui/ResultsTree.gd`
  - depends on: `res://addons/gut/images/red.png`
  - depends on: `res://addons/gut/images/green.png`
  - depends on: `res://addons/gut/images/yellow.png`
- `res:///addons/gut/gui/RunAtCursor.gd`
  - depends on: `res://addons/gut/editor_caret_context_notifier.gd`
- `res:///addons/gut/gui/RunExternally.gd`
  - depends on: `res://addons/gut/gui/editor_globals.gd`
- `res:///addons/gut/gui/RunResults.gd`
  - depends on: `res://addons/gut/gui/editor_globals.gd`
- `res:///addons/gut/gui/ShellOutOptions.gd`
  - depends on: `res://addons/gut/gui/editor_globals.gd`
  - depends on: `res://addons/gut/gui/EditorRadioButton.tres`
- `res:///addons/gut/gui/ShortcutDialog.gd`
  - depends on: `res://addons/gut/gui/editor_globals.gd`
- `res:///addons/gut/gui/about.gd`
  - depends on: `res://addons/gut/gui/editor_globals.gd`
- `res:///addons/gut/gui/editor_globals.gd`
  - depends on: `res://addons/gut/gui/gut_user_preferences.gd`
- `res:///addons/gut/gui/gut_config_gui.gd`
  - depends on: `res://addons/gut/gui/panel_controls.gd`
  - depends on: `res://addons/gut/gut_config.gd`
- `res:///addons/gut/gui/gut_logo.gd`
  - depends on: `res://addons/gut/gui/editor_globals.gd`
  - depends on: `res://addons/gut/images/GutIconV2_no_shine.png`
  - depends on: `res://addons/gut/images/GutIconV2_base.png`
- `res:///addons/gut/gui/option_maker.gd`
  - depends on: `res://addons/gut/gui/panel_controls.gd`
- `res:///addons/gut/gui/run_from_editor.gd`
  - depends on: `res://addons/gut/gut_loader.gd`
  - depends on: `res://addons/gut/gui/GutRunner.tscn`
- `res:///addons/gut/gut_cmdln.gd`
  - depends on: `res://addons/gut/version_conversion.gd`
  - depends on: `res://addons/gut/gut_loader.gd`
  - depends on: `res://addons/gut/cli/gut_cli.gd`
- `res:///addons/gut/gut_loader.gd`
  - depends on: `res://addons/gut/warnings_manager.gd`
  - depends on: `res://addons/gut/utils.gd`
- `res:///addons/gut/gut_plugin.gd`
  - depends on: `res://addons/gut/version_conversion.gd`
  - depends on: `res://addons/gut/gut_menu.gd`
  - depends on: `res://addons/gut/gui/GutEditorWindow.tscn`
  - depends on: `res://addons/gut/gui/GutBottomPanel.tscn`
  - depends on: `res://addons/gut/gui/editor_globals.gd`
  - depends on: `res://addons/gut/gui/editor_globals.gd`
- `res:///addons/gut/hook_script.gd`
  - depends on: `res://addons/gut/junit_xml_export.gd`
- `res:///addons/gut/lazy_loader.gd`
  - depends on: `res://addons/gut/thing_counter.gd`
  - depends on: `res://addons/gut/warnings_manager.gd`
- `res:///addons/gut/test.gd`
  - depends on: `res://addons/gut/signal_watcher.gd`
  - depends on: `res://addons/gut/test.gd`
  - depends on: `res://addons/gut/gut.gd`
- `res:///addons/gut/utils.gd`
  - depends on: `res://addons/gut/GutScene.tscn`
  - depends on: `res://addons/gut/lazy_loader.gd`
  - depends on: `res://addons/gut/version_numbers.gd`
  - depends on: `res://addons/gut/warnings_manager.gd`
  - depends on: `res://addons/gut/gui/editor_globals.gd`
  - depends on: `res://addons/gut/gui/RunExternally.tscn`
  - depends on: `res://addons/gut/get_editor_interface.gd`
- `res:///addons/gut/version_conversion.gd`
  - depends on: `res://addons/gut/gui/editor_globals.gd`
- `res:///addons/loggie/loggie.gd`
  - depends on: `res://addons/loggie/channels/terminal.gd`
  - depends on: `res://addons/loggie/channels/discord.gd`
  - depends on: `res://addons/loggie/channels/slack.gd`
- `res:///autoload/EconomyManager.gd`
  - depends on: `resource_path`
  - depends on: `resource_path`
  - depends on: `resource_path`
- `res:///autoload/EventManager.gd`
  - depends on: `res://data/traits/Trait_Rival.tres`
- `res:///autoload/ProjectilePoolManager.gd`
  - depends on: `res://scenes/effects/Projectile.tscn`
- `res:///autoload/SettlementManager.gd`
  - depends on: `resource_path`
  - depends on: `resource_path`
  - depends on: `resource_path`
  - depends on: `resource_path`
- `res:///data/buildings/Base_Building.gd`
  - depends on: `res://ui/components/BuildingInfoHUD.tscn`
  - depends on: `res://scripts/utility/IsoPlaceholder.gd`
- `res:///scenes/missions/RaidMission.gd`
  - depends on: `res://scenes/units/PlayerVikingRaider.tscn`
- `res:///scenes/missions/RaidObjectiveManager.gd`
  - depends on: `res://ui/themes/VikingDynastyTheme.tres`
- `res:///scenes/world_map/MacroMap.gd`
  - depends on: `res://ui/RaidPrepWindow.tscn`
- `res:///scripts/buildings/SettlementBridge.gd`
  - depends on: `res://data/buildings/Bldg_Wall.tres`
  - depends on: `res://ui/EndOfYear_Popup.tscn`
  - depends on: `res://scenes/units/VikingRaider.tscn`
- `res:///scripts/ui/PauseMenu.gd`
  - depends on: `res://data/units/Unit_PlayerRaider.tres`
  - depends on: `res://data/units/Unit_PlayerRaider.tres`
- `res:///scripts/ui/WinterCourt_UI.gd`
  - depends on: `res://data/units/Unit_Drengr.tres`
- `res:///scripts/units/SquadLeader.gd`
  - depends on: `res://scripts/units/SquadSoldier.gd`
  - depends on: `res://scripts/units/SquadLeader.gd`
- `res:///scripts/utility/GridVisualizer.gd`
  - depends on: `res://scripts/utility/UnitPathDrawer.gd`
- `res:///scripts/utility/UnitSpawner.gd`
  - depends on: `res://scripts/units/SquadLeader.gd`
- `res:///test/base/GutTestBase.gd`
  - depends on: `res://data/units/Unit_PlayerRaider.tres`
- `res:///test/fixtures/SmokeTest.gd`
  - depends on: `res://scripts/utility/UnitSpawner.gd`
- `res:///test/fixtures/TestUtils.gd`
  - depends on: `res://ui/EndOfYear_Popup.gd`
  - depends on: `res://scripts/buildings/SettlementBridge.gd`
- `res:///test/integration/test_building_placement.gd`
  - depends on: `res://autoload/SettlementManager.gd`
- `res:///test/integration/test_terrain_solids.gd`
  - depends on: `res://autoload/SettlementManager.gd`
- `res:///test/integration/test_winter_systems.gd`
  - depends on: `res://ui/WinterCourt_UI.tscn`
- `res:///test/test_year_cycle.gd`
  - depends on: `res://data/units/Bondi.tres`
- `res:///test/unit/test_spawn_logic.gd`
  - depends on: `res://autoload/SettlementManager.gd`
- `res:///tools/AIContentImporter.gd`
  - depends on: `res://scenes/units/PlayerVikingRaider.tscn`
  - depends on: `res://scenes/buildings/Base_Building.tscn`
- `res:///tools/AIContentImporter_Template.gd`
  - depends on: `res://scenes/units/EnemyVikingRaider.tscn`
  - depends on: `res://scenes/buildings/Base_Building.tscn`
- `res:///tools/ContextGenerator_Gemini.gd`
  - depends on: ` in line or `
- `res:///tools/EnemyBaseEditor.gd`
  - depends on: `resource_path`
- `res:///tools/GenerateBandContent.gd`
  - depends on: `res://ui/assets/res_peasant.png`
- `res:///tools/ThemeBuilder.gd`
  - depends on: `wood_bg.png`
  - depends on: `parchment_bg.png`
  - depends on: `resource_tag.png`
  - depends on: `tooltip_bg.png`
- `res:///ui/DynastyUI.gd`
  - depends on: `res://ui/components/HeirCard.tscn`
  - depends on: `res://textures/placeholders/unit_placeholder.png`
- `res:///ui/StorefrontUI.gd`
  - depends on: `res://data/legacy/LegacyUpgradeData.gd`
  - depends on: `res://ui/components/RichTooltipButton.gd`
  - depends on: `res://data/units/`
- `res:///ui/seasonal/SummerAllocation_UI.gd`
  - depends on: `resource_path`
  - depends on: `resource_path`
  - depends on: `resource_path`
  - depends on: `resource_path`
  - depends on: `resource_path`
  - depends on: `resource_path`