// Levels.js - Certified 100% Mathematically Solvable Level Configurations for Foxtail
// Featuring genuine Longcat-style irregular trench contours (X = void ground), strategic tree stumps (#), and verified solutions.
.pragma library

var LEVELS = [
    {
        "name": "Glacier Corner",
        "width": 4,
        "height": 4,
        "grid": [
            ".#XX",
            "..XX",
            "S...",
            "...."
        ],
        "solution": [
            "D",
            "R",
            "U",
            "L",
            "U",
            "L",
            "U"
        ],
        "moves": 7,
        "num_sols": 1,
        "score": 157,
        "id": 1
    },
    {
        "name": "The Winding Burrow",
        "width": 4,
        "height": 5,
        "grid": [
            "....",
            ".XX.",
            "#...",
            "..XX",
            ".SXX"
        ],
        "solution": [
            "L",
            "U",
            "R",
            "U",
            "R",
            "U",
            "L",
            "D"
        ],
        "moves": 8,
        "num_sols": 1,
        "score": 160,
        "id": 2
    },
    {
        "name": "Horseshoe Bend",
        "width": 4,
        "height": 5,
        "grid": [
            "....",
            ".XX.",
            "SXX.",
            "....",
            ".#.."
        ],
        "solution": [
            "U",
            "R",
            "D",
            "L",
            "U",
            "L",
            "D"
        ],
        "moves": 7,
        "num_sols": 1,
        "score": 157,
        "id": 3
    },
    {
        "name": "Canyon Pass",
        "width": 4,
        "height": 4,
        "grid": [
            ".S..",
            ".X.#",
            ".X..",
            "...."
        ],
        "solution": [
            "L",
            "D",
            "R",
            "U",
            "L",
            "U",
            "R"
        ],
        "moves": 7,
        "num_sols": 1,
        "score": 157,
        "id": 4
    },
    {
        "name": "Double Serpentine",
        "width": 5,
        "height": 5,
        "grid": [
            ".....",
            "#XXX.",
            ".....",
            ".XXXS",
            "....."
        ],
        "solution": [
            "D",
            "L",
            "U",
            "R",
            "U",
            "L"
        ],
        "moves": 6,
        "num_sols": 1,
        "score": 154,
        "id": 5
    },
    {
        "name": "The Hourglass",
        "width": 3,
        "height": 5,
        "grid": [
            "#..",
            "...",
            ".XS",
            "...",
            "..."
        ],
        "solution": [
            "U",
            "L",
            "D",
            "L",
            "D",
            "R",
            "U",
            "L"
        ],
        "moves": 8,
        "num_sols": 1,
        "score": 160,
        "id": 6
    },
    {
        "name": "Arctic Donut",
        "width": 5,
        "height": 4,
        "grid": [
            "..S..",
            ".XX.#",
            ".XX..",
            "....."
        ],
        "solution": [
            "L",
            "D",
            "R",
            "U",
            "L",
            "U",
            "R"
        ],
        "moves": 7,
        "num_sols": 1,
        "score": 157,
        "id": 7
    },
    {
        "name": "Frost Cross",
        "width": 4,
        "height": 4,
        "grid": [
            "X##X",
            "....",
            ".S..",
            "X..X"
        ],
        "solution": [
            "L",
            "U",
            "R",
            "D",
            "L",
            "D",
            "L"
        ],
        "moves": 7,
        "num_sols": 1,
        "score": 167,
        "id": 8
    },
    {
        "name": "Pine Chimney",
        "width": 4,
        "height": 4,
        "grid": [
            "X..X",
            "X..X",
            ".S..",
            "...."
        ],
        "solution": [
            "L",
            "D",
            "R",
            "U",
            "L",
            "U",
            "L",
            "D"
        ],
        "moves": 8,
        "num_sols": 1,
        "score": 140,
        "id": 9
    },
    {
        "name": "Snow Serpent",
        "width": 4,
        "height": 5,
        "grid": [
            "...#",
            "XX..",
            "#...",
            "..XX",
            "...S"
        ],
        "solution": [
            "L",
            "U",
            "R",
            "U",
            "R",
            "U",
            "L",
            "U",
            "L"
        ],
        "moves": 9,
        "num_sols": 1,
        "score": 173,
        "id": 10
    },
    {
        "name": "Twin Alcoves",
        "width": 5,
        "height": 4,
        "grid": [
            "##...",
            "XX.XX",
            ".S...",
            "....."
        ],
        "solution": [
            "L",
            "D",
            "R",
            "U",
            "L",
            "U",
            "R"
        ],
        "moves": 7,
        "num_sols": 1,
        "score": 167,
        "id": 11
    },
    {
        "name": "Crescent Glade",
        "width": 5,
        "height": 4,
        "grid": [
            ".....",
            ".XXX.",
            ".....",
            "#.S.."
        ],
        "solution": [
            "L",
            "U",
            "L",
            "U",
            "R",
            "D",
            "L",
            "U",
            "L"
        ],
        "moves": 9,
        "num_sols": 1,
        "score": 163,
        "id": 12
    },
    {
        "name": "Frost Keyhole",
        "width": 5,
        "height": 5,
        "grid": [
            "XX.XX",
            "XX.XX",
            "#....",
            "..#S.",
            "....."
        ],
        "solution": [
            "U",
            "R",
            "D",
            "L",
            "U",
            "R",
            "U",
            "R",
            "U"
        ],
        "moves": 9,
        "num_sols": 1,
        "score": 173,
        "id": 13
    },
    {
        "name": "Twin Islands",
        "width": 5,
        "height": 5,
        "grid": [
            ".....",
            ".X#XS",
            ".#...",
            ".X.X.",
            "....."
        ],
        "solution": [
            "U",
            "L",
            "D",
            "R",
            "U",
            "L",
            "D"
        ],
        "moves": 7,
        "num_sols": 1,
        "score": 167,
        "id": 14
    },
    {
        "name": "Twin Niches",
        "width": 4,
        "height": 5,
        "grid": [
            ".S..",
            ".X..",
            "....",
            "..X.",
            "...."
        ],
        "solution": [
            "L",
            "D",
            "R",
            "U",
            "L",
            "D",
            "L",
            "D"
        ],
        "moves": 8,
        "num_sols": 1,
        "score": 140,
        "id": 15
    },
    {
        "name": "Spiral Labyrinth",
        "width": 5,
        "height": 5,
        "grid": [
            ".....",
            ".XXX.",
            ".X...",
            ".X.XX",
            ".S..#"
        ],
        "solution": [
            "L",
            "U",
            "R",
            "D",
            "L",
            "D",
            "R"
        ],
        "moves": 7,
        "num_sols": 1,
        "score": 157,
        "id": 16
    },
    {
        "name": "Offset Rings",
        "width": 5,
        "height": 5,
        "grid": [
            "..S..",
            ".XX..",
            ".....",
            "..XX.",
            "....."
        ],
        "solution": [
            "L",
            "D",
            "R",
            "U",
            "L",
            "D",
            "L",
            "D"
        ],
        "moves": 8,
        "num_sols": 1,
        "score": 140,
        "id": 17
    },
    {
        "name": "Grand Spiral",
        "width": 6,
        "height": 5,
        "grid": [
            "......",
            ".XXXXS",
            ".X....",
            ".X.XX.",
            "...#.."
        ],
        "solution": [
            "U",
            "L",
            "D",
            "R",
            "U",
            "R",
            "D",
            "L"
        ],
        "moves": 8,
        "num_sols": 1,
        "score": 160,
        "id": 18
    },
    {
        "name": "Notched Meadow",
        "width": 4,
        "height": 4,
        "grid": [
            "....",
            "S...",
            "....",
            ".X.."
        ],
        "solution": [
            "U",
            "R",
            "D",
            "L",
            "U",
            "L",
            "D",
            "L",
            "D"
        ],
        "moves": 9,
        "num_sols": 1,
        "score": 143,
        "id": 19
    },
    {
        "name": "Glacier Wrench",
        "width": 4,
        "height": 5,
        "grid": [
            "...X",
            ".X..",
            ".S..",
            "....",
            "X..."
        ],
        "solution": [
            "R",
            "U",
            "L",
            "U",
            "L",
            "D",
            "R",
            "D",
            "L"
        ],
        "moves": 9,
        "num_sols": 1,
        "score": 143,
        "id": 20
    },
    {
        "name": "Step Drift",
        "width": 5,
        "height": 5,
        "grid": [
            ".S..X",
            "...XX",
            "..XXX",
            ".....",
            "....."
        ],
        "solution": [
            "L",
            "D",
            "R",
            "U",
            "L",
            "U",
            "R",
            "U",
            "R"
        ],
        "moves": 9,
        "num_sols": 1,
        "score": 143,
        "id": 21
    },
    {
        "name": "Cavern Chasm",
        "width": 6,
        "height": 5,
        "grid": [
            "......",
            ".XX#X.",
            ".S....",
            "......",
            "..X..."
        ],
        "solution": [
            "R",
            "U",
            "L",
            "D",
            "R",
            "U",
            "R",
            "D",
            "L"
        ],
        "moves": 9,
        "num_sols": 1,
        "score": 163,
        "id": 22
    },
    {
        "name": "Frost Maze",
        "width": 5,
        "height": 5,
        "grid": [
            "..S..",
            ".X...",
            ".#.X.",
            ".X...",
            "....."
        ],
        "solution": [
            "L",
            "D",
            "R",
            "U",
            "L",
            "D",
            "L",
            "D",
            "R"
        ],
        "moves": 9,
        "num_sols": 1,
        "score": 163,
        "id": 23
    },
    {
        "name": "Twin Corridors",
        "width": 5,
        "height": 5,
        "grid": [
            "..#XX",
            "...XX",
            ".S...",
            "XX...",
            "XX..."
        ],
        "solution": [
            "L",
            "U",
            "R",
            "D",
            "R",
            "D",
            "R",
            "U",
            "L",
            "D"
        ],
        "moves": 10,
        "num_sols": 1,
        "score": 166,
        "id": 24
    },
    {
        "name": "Asymmetric Trench",
        "width": 5,
        "height": 5,
        "grid": [
            ".....",
            "..SX.",
            "...X.",
            ".X...",
            "....."
        ],
        "solution": [
            "U",
            "R",
            "D",
            "L",
            "U",
            "R",
            "D",
            "R",
            "D",
            "R"
        ],
        "moves": 10,
        "num_sols": 1,
        "score": 146,
        "id": 25
    },
    {
        "name": "Snow Crown",
        "width": 6,
        "height": 5,
        "grid": [
            "#XS.X#",
            "......",
            "..XX..",
            "......",
            "......"
        ],
        "solution": [
            "R",
            "D",
            "L",
            "D",
            "R",
            "U",
            "L",
            "D",
            "L",
            "U"
        ],
        "moves": 10,
        "num_sols": 1,
        "score": 176,
        "id": 26
    },
    {
        "name": "Fox Snare",
        "width": 4,
        "height": 5,
        "grid": [
            "#...",
            "..XS",
            ".X..",
            "....",
            "...."
        ],
        "solution": [
            "U",
            "L",
            "D",
            "L",
            "D",
            "R",
            "U",
            "L",
            "D",
            "L"
        ],
        "moves": 10,
        "num_sols": 1,
        "score": 166,
        "id": 27
    },
    {
        "name": "Fortress Courtyard",
        "width": 6,
        "height": 5,
        "grid": [
            "......",
            "#XXXX.",
            "......",
            ".XXXXS",
            "......"
        ],
        "solution": [
            "D",
            "L",
            "U",
            "R",
            "U",
            "L"
        ],
        "moves": 6,
        "num_sols": 1,
        "score": 154,
        "id": 28
    },
    {
        "name": "Two Rooms Doorway",
        "width": 6,
        "height": 4,
        "grid": [
            "...X..",
            "...XS.",
            ".#....",
            "...X.."
        ],
        "solution": [
            "U",
            "R",
            "D",
            "L",
            "U",
            "L",
            "D",
            "L",
            "U",
            "R",
            "D",
            "L"
        ],
        "moves": 12,
        "num_sols": 1,
        "score": 172,
        "id": 29
    },
    {
        "name": "Boreal Fork",
        "width": 7,
        "height": 5,
        "grid": [
            "#..X...",
            "...X...",
            ".#.....",
            ".XXSXX.",
            "......."
        ],
        "solution": [
            "U",
            "L",
            "U",
            "L",
            "D",
            "L",
            "D",
            "R",
            "U",
            "L",
            "D",
            "R",
            "U"
        ],
        "moves": 13,
        "num_sols": 1,
        "score": 185,
        "id": 30
    }
];

function getLevelCount() {
    return LEVELS.length;
}

function getLevel(index) {
    if (index >= 1 && index <= LEVELS.length) {
        return LEVELS[index - 1];
    }
    if (index >= 0 && index < LEVELS.length) {
        return LEVELS[index];
    }
    return null;
}
