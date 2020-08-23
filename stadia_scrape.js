
var game = {
    "achievements": [],
    "title": 'SteamWorld Quest: Hand of Gilgamech',
};

var achievementElements = document.getElementsByClassName("h6J22d cWe8yc QAAyWd");

for (var a = 0; a < achievementElements.length; a++) {

    var achievement = {
        "name": '',
        'description' : '',
        "image": ''
    };
    var achievementNode = achievementElements.item(a).children;

    achievement['image'] = achievementNode[0].firstChild.style.backgroundImage.slice(4, -1).replace(/["']/g, "");
    achievement['name'] = achievementNode[1].children[0].children[0].innerText;
    achievement['description'] = achievementNode[1].children[0].children[0].innerText;

    game['achievements'].push(achievement);
}


console.log(game);
