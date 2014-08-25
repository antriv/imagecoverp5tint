import gab.opencv.*;
import controlP5.*;
import java.awt.Rectangle;
import java.util.Arrays;

// constants
int SCREENWIDTH = 1280;
int SCREENHEIGHT = 1000;
int ARTWORKSTARTX = 400;
int ARTWORKSTARTY = 75;
int COVERWIDTH = 200;
int COVERHEIGHT = 300;
float COVERRATIO = float(COVERWIDTH) / float(COVERHEIGHT);
int MARGIN = 5;
int IMAGEMARGIN = 10;
int TITLEHEIGHT = 50;
int AUTHORHEIGHT = 25;
int BACKGROUNDCOLOR = 128;
int MAXAUTHORCHAR = 24;

PGraphics pg;

OpenCV opencv;
Rectangle[] faces;

ControlP5 cp5;

DropdownList titleFontList;
DropdownList authorFontList;

int baseSaturation = 60;//70;
int baseBrightness = 80;//85;
int imageBrightness = -200;
int imageAlpha = 10;
int topMargin = 220;
int textBackgroundAlpha = 210;
int lineThickness = 0;
boolean faceDetect = false;
boolean invert = true;
boolean batch = false;

ArrayList<PImage> images;
ArrayList<PImage> covers;

PFont titleFont;
PFont authorFont;
int titleSize;
int authorSize;

color baseColor;
color textColor;
boolean refresh = true;
String[] bookList;
int currentBook = 0;
int currentId = 0;
String title = "";
String author = "";
String filename = "";
String baseFolder = "";

int startTime = 0;
int imageCounter = 0;
int startID = 0;

void setup() {
  selectFolder("Select a folder to process:", "folderSelected");
  size(SCREENWIDTH, SCREENHEIGHT);
  background(255);
  noStroke();
  images = new ArrayList<PImage>();
  covers = new ArrayList<PImage>();
  cp5 = new ControlP5(this);
  pg = createGraphics(COVERWIDTH, COVERHEIGHT);
  controlP5Setup();
  loadData();
}

void controlP5Setup() {
  cp5.addSlider("baseSaturation")
    .setPosition(10,5)
    .setRange(0,100)
    .setSize(200,10)
    .setId(3)
    ;
  cp5.addSlider("baseBrightness")
    .setPosition(10,20)
    .setRange(0,100)
    .setSize(200,10)
    .setId(3)
    ;
  cp5.addSlider("imageAlpha")
    .setPosition(10,35)
    .setRange(0,200)
    .setSize(200,10)
    .setId(3)
    ;
  cp5.addSlider("topMargin")
    .setPosition(300,5)
    .setRange(MARGIN,COVERHEIGHT-MARGIN)
    .setSize(200,10)
    .setId(3)
    ;
  cp5.addSlider("textBackgroundAlpha")
    .setPosition(300,20)
    .setRange(0,255)
    .setSize(200,10)
    .setId(3)
    ;
  cp5.addSlider("lineThickness")
    .setPosition(300,35)
    .setRange(0,10)
    .setSize(200,10)
    .setId(3)
    ;
  cp5.addToggle("faceDetect")
     .setPosition(610,5)
     .setSize(50,20)
     .setMode(ControlP5.SWITCH)
     ;
  cp5.addToggle("invert")
     .setPosition(670,5)
     .setSize(50,20)
     .setMode(ControlP5.SWITCH)
     ;
  cp5.addToggle("batch")
     .setPosition(730,5)
     .setSize(50,20)
     .setMode(ControlP5.SWITCH)
     ;

  cp5.addTextfield("inputID")
     .setPosition(790,5)
     .setSize(100,20)
     .setFocus(true)
     .setColor(color(255,0,0))
     ;

  titleFontList = cp5.addDropdownList("titleList")
         .setPosition(900, 15)
         .setSize(150, 200)
         ;

  titleFontList.captionLabel().toUpperCase(true);
  titleFontList.captionLabel().set("Font");
  titleFontList.addItem("ACaslonPro-Regular-16.vlw", 0);
  titleFontList.addItem("ACaslonPro-Italic-16.vlw", 1);
  titleFontList.addItem("ACaslonPro-Semibold-18.vlw", 2);
  titleFontList.addItem("AvenirNext-Bold-18.vlw", 3);
  titleFontList.addItem("AvenirNext-Regular-18.vlw", 4);
  titleFontList.addItem("AvenirNext-Bold-16.vlw", 5);
  titleFontList.addItem("AvenirNext-Bold-14.vlw", 6);
  titleFontList.setIndex(6);

  authorFontList = cp5.addDropdownList("authorList")
         .setPosition(1070, 15)
         .setSize(150, 200)
         ;

  authorFontList.captionLabel().toUpperCase(true);
  authorFontList.captionLabel().set("Font");
  authorFontList.addItem("ACaslonPro-Italic-14.vlw", 0);
  authorFontList.addItem("ACaslonPro-Regular-16.vlw", 1);
  authorFontList.addItem("AvenirNext-Bold-14.vlw", 2);
  authorFontList.addItem("AvenirNext-Regular-14.vlw", 3);
  authorFontList.setIndex(2);
}

void draw() {
  background(255);
  fill(50);
  rect(0, 0, SCREENWIDTH, 50);
  if (baseFolder!="") {
    int tempID = int(cp5.get(Textfield.class,"inputID").getText());
    if (tempID!=0 && tempID!=startID) {
      startID = tempID;
      int index = getIndexForBookId(startID);
      println("tempID:" + tempID + " index:" + index);
      if (index!=-1) {
        currentBook = index;
      }
    }
    if (refresh) {
      refresh = false;
      parseBook();
      createCovers();
      if (images.size() == 0) {
        println("BOOK HAS NO USEFUL IMAGES");
      }
    }
    if (images.size() > 0) {
      drawCovers();
    }
  }
  if (batch) {
    saveCurrent();
    refresh = true;
    currentBook++;
    if (currentBook >= bookList.length) {
      currentBook = 0;
      batch = false;
      refresh = false;
      int endTime = millis();
      int seconds = round((endTime - startTime)*.001);
      int minutes = round(seconds/60);
      println("Processing " + imageCounter + " images for " + bookList.length + " books took " + minutes + " minutes (" + seconds + " seconds)");
    }
  }
}

void drawCovers() {
  int i, l;
  l = images.size();
  int colWidth = COVERWIDTH + MARGIN;
  int rowHeight = COVERHEIGHT + MARGIN;
  int xini = MARGIN;
  int yini = 60;
  int cols = floor(SCREENWIDTH / (colWidth));
  int col = 0;
  int row = 0;
  int x = 0;
  int y = 0;
  // println(images);
  for (i=0;i<l;i++) {
    x = xini + (col * (colWidth));
    y = yini + (row * rowHeight);
    image(covers.get(i), x, y);
    col++;
    if (col >= cols) {
      col = 0;
      row++;
    }
  }
}

void createCovers() {
  covers.clear();
  int i, l = images.size();;

  if (l==0) return;

  for (i=0;i<l;i++) {
    imageCounter++;
    covers.add(createCover(i));
  }
}

PImage createCover(int index) {
  pg.clear();
  pg.beginDraw();
  drawBackground(pg, 0, 0);
  drawArtwork(pg, index, 0, 0);
  drawText(pg, 0, 0);
  pg.endDraw();
  return pg.get();
}

void loadData() {
  bookList = loadStrings("illustration_list.json");
  // config = loadStrings("ids.txt");
}

void getBookImages(JSONArray json_images) {
  images.clear();

  int minSize = 200;

  PImage temp, img, imgBW;
  int i;
  float w, h;
  int maxHeight = 140;

  IntList indexes = new IntList();

  int l = json_images.size();

  // println("ratio:" + COVERRATIO);
  for (i=0;i<l;i++) {
    String path = json_images.getString(i);

    if (path.toLowerCase().indexOf("cover") != -1
      || path.toLowerCase().indexOf("title") != -1
      || path.toLowerCase().indexOf("page-images") != -1
      || (!path.endsWith(".jpg") && !path.endsWith(".png"))) {
      // skip generic covers (usually named "cover.jpg" or "title.jpg")
      continue;
    }

    path = baseFolder + path.replace("./","");
    // println("loading:" + path);
    temp = loadImage(path);
    if (temp == null || temp.width <= 0 || temp.height <= 0) {
      continue;
    }
    // check for faces (not faeces)
    if (faceDetect) {
      opencv = new OpenCV(this, temp);
      opencv.loadCascade(OpenCV.CASCADE_FRONTALFACE);
      faces = opencv.detect();
      if (faces.length > 0) {
        temp = temp.get(faces[0].x-40, faces[0].y-40, faces[0].width+60, faces[0].height+100);
        // for (int i = 0; i < faces.length; i++) {
        //   rect(faces[i].x, faces[i].y, faces[i].width, faces[i].height);
        // }
      }
    }
    // end opencv
    w = temp.width;
    h = temp.height;
    float ratio = w/h;
    // println("i1:" + i + " w:" + temp.width + " h:" + temp.height + " r:" + ratio);
    if (ratio >= COVERRATIO) {
      // temp.resize(COVERWIDTH-IMAGEMARGIN*2, 0);
      temp.resize(0, COVERHEIGHT + MARGIN*3);
      imgBW = temp.get(int((temp.width-COVERWIDTH)*.5)+MARGIN, MARGIN, COVERWIDTH, COVERHEIGHT);
      // println("wider");
    } else {
      // temp.resize(0, maxHeight);
      temp.resize(COVERWIDTH + MARGIN*3, 0);
      imgBW = temp.get(MARGIN, int((temp.height-COVERHEIGHT)*.5)+MARGIN, COVERWIDTH, COVERHEIGHT);
      // println("taller");
    }
    // println("i2:" + i + " w:" + temp.width + " h:" + temp.height);
    // println("i3:" + i + " w:" + int((temp.width-COVERWIDTH)*.5) + " h:" + int((temp.height-COVERHEIGHT)*.5));
    imgBW.filter(GRAY);
    // if (invert) {
    //   imgBW.filter(INVERT);
    // }
    img = imgBW.get(0, 0, COVERWIDTH, COVERHEIGHT);
    imgBW = imgBW.get(0, topMargin-MARGIN, COVERWIDTH, COVERHEIGHT-topMargin+MARGIN);

    pg.clear();
    pg.beginDraw();
    pg.background(baseColor);
    pg.tint(baseColor);
    pg.image(img, 0, 0);
    // for bicolor photo
    pg.noTint();
    // pg.image(imgBW, 0, topMargin-MARGIN);
    // end bicolor photo
    pg.endDraw();
    images.add(pg.get());
  }
}

JSONObject getBook(int index) {
  int l = bookList.length;
  int i;
  JSONObject book = new JSONObject();
  book = JSONObject.parse(bookList[index]);
  return book;
}

int getIndexForBookId(int id) {
  int l = bookList.length;
  int i;
  JSONObject book = new JSONObject();
  for (i=0;i<l;i++) {
    book = JSONObject.parse(bookList[i]);
    int bid = book.getInt("identifier");
    if (id == bid) {
      return i;
    }
  }
  return -1;
}

void parseBook() {
  JSONObject book = getBook(currentBook);

  currentId = book.getInt("identifier");

  println("book id:" + currentId);

  title = book.getString("title");
  String subtitle = "";
  String json_author = "";

  try {
    subtitle = book.getString("subtitle");
  }
  catch (Exception e) {
    println("book has no subtitle");
  }
  if (!subtitle.equals("")) {
    title += ": " + subtitle;
  }
  title = title.toUpperCase();

  try {
    json_author = book.getString("authors_long");
  }
  catch (Exception e) {
    println("book has no authors");
  }
  if (!json_author.equals("")) {
    author = json_author;
  } else {
    author = "";
  }

  // now try the short author
  json_author = "";

  try {
    json_author = book.getString("authors_short");
  }
  catch (Exception e) {
    println("book has no short authors");
  }
  if (!json_author.equals("") && author.length() > MAXAUTHORCHAR) {
    author = json_author;
  }

  filename = book.getString("identifier") + ".png";

  processColors();

  JSONArray json_images = book.getJSONArray("illustrations");
  if (json_images.size() > 0) {
    getBookImages(json_images);
  }
}

void processColors() {
  int counts = title.length() + author.length();
  int colorSeed = int(map(counts, 1, 80, 30, 260));
  colorMode(HSB, 360, 100, 100);
  color lightColor = color((colorSeed+180)%360, baseSaturation-20, baseBrightness+40);
  color darkColor = color(colorSeed, baseSaturation, baseBrightness-20);
  textColor = lightColor;
  baseColor = darkColor;
  if (invert) {
    baseColor = lightColor;
    textColor = darkColor;
  }
  // println("baseColor:"+baseColor);
  colorMode(RGB, 255);
}

void drawArtwork(PGraphics g, int index, int _x, int _y) {
  PImage img = images.get(index);
  int x = _x; //+int((COVERWIDTH - img.width) * .5);
  int y = _y; //+int((COVERHEIGHT - img.height) * .5);
  g.image(img, x, y);
}

void drawBackground(PGraphics g, int x, int y) {
  g.fill(BACKGROUNDCOLOR);
  g.rect(x, y, COVERWIDTH, COVERHEIGHT);
}

void drawText(PGraphics g, int x, int y) {
  //…
  g.noStroke();
  // for text box
  g.fill(textColor);
  g.rect(x, y+topMargin-lineThickness-MARGIN, COVERWIDTH, lineThickness);
  if (invert) {
    g.fill(255, textBackgroundAlpha);
  } else {
    g.fill(0, textBackgroundAlpha);
  }
  g.rect(x, y+topMargin-MARGIN, COVERWIDTH, COVERHEIGHT-topMargin+MARGIN);
  // end text box
  g.fill(textColor);
  g.textFont(titleFont, titleSize);
  g.textLeading(titleSize);
  g.textAlign(LEFT);
  g.text(title, x+MARGIN, y+topMargin, COVERWIDTH - (2 * MARGIN), TITLEHEIGHT);
  g.textLeading(authorSize);
  g.textFont(authorFont, authorSize);
  g.text(author, x+MARGIN, y+topMargin+TITLEHEIGHT+MARGIN, COVERWIDTH - (2 * MARGIN), AUTHORHEIGHT);
}

void saveCurrent() {
  int i, l;
  l = images.size();
  // println(images);
  for (i=0;i<l;i++) {
    // save here
    PImage temp = covers.get(i); // get(x, y, COVERWIDTH, COVERHEIGHT);
    temp.save("output/" + currentId + "/cover_" + currentId + "_" + i + ".png");
    // end save
  }

}

void keyPressed() {
  if (key == ' ') {
    refresh = true;
    currentBook++;
  } else if (key == 's') {
    saveCurrent();
  }

  if (key == CODED) {
    refresh = true;
    if (keyCode == LEFT) {
      currentBook--;
    } else if (keyCode == RIGHT) {
      currentBook++;
    }
  }
  if (currentBook >= bookList.length) {
    currentBook = 0;
  }
  if (currentBook < 0) {
    currentBook = bookList.length-1;
  }
}

void controlEvent(ControlEvent theEvent) {
  if (theEvent.isController()) {
    if (theEvent.getController().getName().equals("batch")) {
      startTime = millis();
    }
  }

  if (theEvent.isGroup()) {
    // an event from a group e.g. scrollList
    println(theEvent.group().value()+" from "+theEvent.group());
  } else {
    refresh = true;
  }

  if(theEvent.isAssignableFrom(Textfield.class)) {
    println("controlEvent: accessing a string from controller '"
            +theEvent.getName()+"': "
            +theEvent.getStringValue()
            );
  }

  if(theEvent.isGroup() && theEvent.name().equals("titleList")){
    int index = (int)theEvent.group().value();
    String font = titleFontList.getItem(index).getName();
    println("index:"+index + " font:" + font);
    String suffix = font.substring(font.lastIndexOf("-")+1,font.lastIndexOf("."));
    int fontSize = int(suffix);
    println("size:" + suffix);
    titleFont = loadFont(font);
    titleSize = fontSize;
    refresh = true;
  }

  if(theEvent.isGroup() && theEvent.name().equals("authorList")){
    int index = (int)theEvent.group().value();
    String font = authorFontList.getItem(index).getName();
    println("index:"+index + " font:" + font);
    String suffix = font.substring(font.lastIndexOf("-")+1,font.lastIndexOf("."));
    int fontSize = int(suffix);
    println("size:" + suffix);
    authorFont = loadFont(font);
    authorSize = fontSize;
    refresh = true;
  }
}

void folderSelected(File selection) {
  if (selection == null) {
    println("Window was closed or the user hit cancel.");
  } else {
    baseFolder = selection.getAbsolutePath() + "/";
    println("User selected " + baseFolder);
  }
}


