@echo off
REM Create_Flutter_Project_Structure.bat

REM  This script creates a basic Flutter project structure.
REM  It assumes you have Flutter installed and in your PATH.

REM  Change "word_trainer" to your desired project name if needed.
SET PROJECT_NAME=word_trainer

REM --- Create the project directory structure ---

IF NOT EXIST lib (
    echo Creating project directory structure...

    mkdir lib
    cd lib

    mkdir config
    mkdir helpers
    mkdir theme

    mkdir domain
    cd domain
        mkdir entities
    cd ..

    mkdir infrastructure
    cd infrastructure
        mkdir models
        mkdir datasources
        mkdir repositories
    cd ..

    mkdir presentation
    cd presentation
        mkdir providers
        mkdir screens
        cd screens
            mkdir home
        cd ..
        mkdir widgets
        cd widgets
          mkdir shared
        cd ..
        mkdir utils
    cd ..
    cd ..
    echo Directory structure created.
) ELSE (
    echo lib directory already exists, skipping structure creation.  Make sure this is your project directory!
    cd lib  REM <--- IMPORTANT:  Still change to the 'lib' directory.
)


REM --- Create (empty) Dart files ---
REM These are just placeholders; you'll need to add your actual code.

REM IMPORTANT: Adjust paths here if you created a new project. These paths
REM            assume you are running this script from INSIDE the 'lib' directory.

echo Creating helper files...
 >helpers\db_helper.dart echo // DBHelper class (database logic)

echo Creating domain entity files...
 >domain\entities\word.dart echo // Word entity
 >domain\entities\practice_session.dart echo // PracticeSession entity
 >domain\entities\practice_history.dart echo // PracticeHistory entity
 >domain\entities\round.dart echo // Round entity

echo Creating infrastructure files...
 >infrastructure\repositories\word_repository.dart echo // WordRepository implementation
 >infrastructure\repositories\practice_session_repository.dart echo //  PracticeSessionRepository

echo Creating presentation files...

 >presentation\screens\home\home_screen.dart echo // HomePage
 >presentation\screens\home\words_tab.dart echo // WordsTab
 >presentation\screens\home\practice_tab.dart echo // PracticeTab
 >presentation\screens\home\spelling_bee_view.dart echo // SpellingBeeView

 >presentation\widgets\shared\word_card.dart echo // WordCard widget
 >presentation\widgets\shared\word_card_practice.dart echo // WordCardPractice widget

echo Creating utility files...
 >presentation\utils\text_to_speech_service.dart echo // TextToSpeechService
 >presentation\utils\translation_service.dart echo // TranslationService
copy ..\main.dart .

echo Files created.

pause