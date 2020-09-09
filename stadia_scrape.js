var achievementElements,
achievementNode,
achievement,
a,
game = {
    "achievements": [],
    "title": "Marvel's Avengers",
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
    achievement['name'] =  achievementNode[1].children[0].children[0].innerText ? achievementNode[1].children[0].children[0].innerText : achievementNode[1].children[0].children[1].innerText;


    if (achievementNode[1].children[0].children[1]) {
        achievement['description'] = achievement['description'] = achievementNode[1].children[0].children[1].innerText 
    }else if (achievementNode[1].children[0].children[2]) {
        achievement['description'] = achievementNode[1].children[0].children[2].innerText
    } else {
        achievement['description'] = ''
    }

    game['achievements'].push(achievement);
}

copy(game);
