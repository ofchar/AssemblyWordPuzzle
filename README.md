# AssemblyWordPuzzle
### General information
AssemblyWordPuzzle is a word search puzzle game written in 8086 assembly. The objective of the game is to identify words that are displayed on the side panel, in a 2D board filled with letters. The words to discover are arranged vertically, horizontally, or diagonally, in any of the reading directions. After all the words to be discovered have been identified, the game is terminated and information about the success and obtained score is displayed.

### Overview
Game starts by reading the data.txt file and printing its first 25 lines to the screen - thats the 'GUI'. Next couple lines of file hold information about words that player needs to find. In each line there is one word, together with information where and how it must be placed on the board. After all words are placed on the board empty spaces are filled with random letters and the game begins. Player moves using *arrow keys*, and selects/deselects letters with *enter* key. 
After all words have been found player is presented with amount of points they got (each correctly selected letter is one point), amount of mistakes they made (each incorrectly selected letter is one mistake) and time it took to finish the game. 

###### Mateusz Owczarek, 2022
