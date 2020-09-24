PImage dogImg;
PImage sheepImg;
int numBoids = 1100;
ArrayList<Boid> Sheeps = new ArrayList<Boid>(numBoids);
float cursor_angle = 0;
float new_cursor_angle = 0;
float dt = .1;
boolean FRAMERATE = false;
boolean PRINT_DEBUG = false;
PrintWriter output;
float framerateSum = 0;
float total_frames = 0;
Vec2 Dog;
Pen Enclosure;
float enclosureX = 90;
float emclosureY = 70;


void setup() {
  size(900, 800);
  noCursor();
  surface.setTitle("Sheep Herding Ala Minecraft");
  //Initial boid objects with positions, random velocities
  for (int i = 0; i < numBoids; i++) {
    float x = random(-360, 360);
    float y = random(-300, 330);
    Sheeps.add(new Boid(x, y));
  }
  strokeWeight(2);
  dogImg = loadImage("dog_face_v4.png");
  sheepImg = loadImage("sheep_face_v2.png");
  imageMode(CENTER);

  output = createWriter("average_framerate_calc.txt");
  Enclosure = new Pen(enclosureX, emclosureY);
  
  Dog = new Vec2(mouseX, mouseY);

}


void draw() {
  background(34, 139, 34); //green background
  fill(10, 120, 10);
  
  // draw the pen that the dog can't get into, but the sheep can
  Enclosure.drawPen();

  // check for dog collision with Enclosure and if there are no collisions, update Dog position
  Vec2 cursor = new Vec2(mouseX, mouseY);
  if (! Enclosure.CheckIfCollision(cursor, false)){
    Dog = cursor;
  }
  
  // draw that dog at cursor location wwith rotation
  if (Dog.x != pmouseX && Dog.y != pmouseY) {
    new_cursor_angle = atan2(Dog.x - pmouseX, Dog.y - pmouseY);  // See about changing this to dot product
    if (abs(new_cursor_angle - cursor_angle) > 0.2) {
      cursor_angle = new_cursor_angle;
    }
  }
  pushMatrix();
  translate(Dog.x, Dog.y);
  rotate(-cursor_angle);
  image(dogImg, 0, 0);
  popMatrix();


  // draw all sheeps
  for (Boid sheep : Sheeps) {
    sheep.DrawBoid();
  }
  // loop through all boid sheeps
  for (Boid sheep : Sheeps) {
    sheep.accel = new Vec2(0, 0);

    // attraction force vars
    Vec2 avgPos = new Vec2(0, 0);
    int countAttra = 0;

    //Alignment force
    Vec2 avgVel = new Vec2(0, 0);
    float countAlign = 0;

    // Boid neighbors looping through
    for (Boid nearest_sheep : Sheeps) { 
      //Separation force (push away from each neighbor if we are too close)
      float distSepAttra = sheep.pos.distanceTo(nearest_sheep.pos);
      if (distSepAttra < .01 || distSepAttra > 50) continue;
      Vec2 seperationForce =  sheep.pos.minus(nearest_sheep.pos).normalized();
      seperationForce.setToLength(400.0/pow(distSepAttra, 2));
      sheep.accel = sheep.accel.plus(seperationForce);

      //Attraction force (move towards the average position of our neighbors)
      if (distSepAttra < 60 && distSepAttra > 0) {
        avgPos.add(nearest_sheep.pos);
        countAttra += 1;
      }

      //Alignment force
      float distAlign = sheep.pos.minus(nearest_sheep.pos).length();
      if (distAlign < 40 && distAlign > 0) {
        avgVel.add(nearest_sheep.vel);
        countAlign += 1;
      }
    }

    // attraction force calcs
    if (countAttra != 0) {
      avgPos.mul(1.0/countAttra);
    }
    if (countAttra >= 1) {
      Vec2 attractionForce = avgPos.minus(sheep.pos);
      attractionForce.normalize();
      attractionForce.times(2);
      attractionForce.clampToLength(sheep.max_force);
      sheep.accel.add(attractionForce);
    }

    //Alignment force calcs
    if (countAlign != 0) {
      avgVel.mul(1.0/countAlign);
    }
    if (countAlign >= 1) {
      Vec2 towards = avgVel.minus(sheep.vel);
      towards.normalize();
      sheep.accel.add(towards.times(2));
    }

    // repel force of dog
    float distance_to_Dog = sheep.pos.distanceTo(Dog);
    if (distance_to_Dog < 120) {
      Vec2 repel;
      sheep.target_speed = sheep.target_speed + 0.15;
      repel = sheep.pos.minus(Dog);
      repel.normalize();
      if (distance_to_Dog != 0) {
        repel.mul(sheep.max_speed * 0.65);
        if (repel.length() <= 0) {
          repel.x = 0;
        }
      }
      sheep.accel.add(repel);
    }
    else{
      sheep.target_speed = 10;
    }
    
    // repel force of the enclosure
    // check if sheep is in area of effect of the enclosure
    if (Enclosure.CheckIfCollision(sheep.pos, true) ){
      Vec2 repel;
      repel = sheep.pos.minus(Enclosure.center);
      repel.normalize();
      sheep.pos.minus(repel);
      repel.mul(sheep.max_speed);
      // check for a closer collision and change sheep velocity if they are too close
      if (Enclosure.CheckIfCollision(sheep.pos, false)){
        if ((sheep.vel.y >= (Enclosure.center.y + Enclosure.y)) &&
        (sheep.vel.y <= (Enclosure.center.y + Enclosure.y + 10)) &&
        (sheep.vel.x >= (Enclosure.center.x - Enclosure.x + 20)) &&
        (sheep.vel.x <= (Enclosure.center.x + Enclosure.x - 20)) ){
          // if the sheep is at the bottom of the pen, we want them to sometimes
          // gravitate into the pen, so negate repel to attract them into the pen
          repel.times(-3);  
          sheep.vel.add(repel);
          break;
        }
        sheep.vel.add(repel);
      }
      // if the sheep is above the enclosure and within it's area of effect
      // set the repel force's y to 0 so that the sheep move either left or right
      // else set repel x to 0 so that the sheep move up or down
      if (sheep.pos.y < Enclosure.center.y - Enclosure.y){
        repel.y = 0;
      }
      else{
        repel.x = 0;
      }
      sheep.accel.add(repel);
    }
    
    //Goal Speed 
    Vec2 targetVel = sheep.vel;
    targetVel.setToLength(sheep.target_speed);
    Vec2 goalSpeedForce = targetVel.minus(sheep.vel);
    goalSpeedForce.times(1);
    goalSpeedForce.clampToLength(sheep.max_force);
    sheep.accel.add(goalSpeedForce);    
  }

  // update position, velocity (and acceleration?)
  for (Boid sheep : Sheeps) {
    sheep.UpdateVecs(dt);
  }
  
  // check if sheep needs to be deleted (it has been herded successfully into the enclosure/pen
  for (int i=0; i < Sheeps.size(); i++) {
    if (Enclosure.CheckToDelete(Sheeps.get(i).pos)) {
      Sheeps.remove(i);
    }
  }  //<>// //<>//
  
  if (FRAMERATE) {
    println(frameRate);
  }

  framerateSum += frameRate;
  total_frames += 1;
  
  if (mousePressed) {
    Boid add_one = new Boid(mouseX, mouseY);
    Sheeps.add(add_one);
  }
}

void keyPressed() {
  if ( key == 's' || key == 'S' ) {
    output.println(framerateSum/total_frames);
    output.println(Sheeps.size());
    output.flush();
    output.close();
    exit();
  }
  if (key == 'd') {
    PRINT_DEBUG = (PRINT_DEBUG) ? false : true;
  }
  if (key == ' ') {
    FRAMERATE = (FRAMERATE) ? false : true;
  }
}

class Boid {
  Vec2 pos, vel, accel, past_pos;
  float max_force, target_speed, max_speed, theta;

  Boid(float x, float y) {
    this.max_force = 10;
    this.target_speed = 10;
    this.max_speed = 20;
    this.theta = 0.0;

    this.pos = new Vec2(x, y);
    this.past_pos = new Vec2(0, 0);
    this.vel = new Vec2(-1+random(2), -1+random(2));  //TODO: Better random angle
    this.vel.normalize();
    this.vel.mul(this.max_speed);
    this.accel = new Vec2(0, 0);
  }

  public void DrawBoid() {
    // rotate sheep in direction of velocity and print
    // find angle between the current position and future (aka velocity)
    // float angle = acos(dot(pos, past_pos) / (pos.length() * past_pos.length()));  // why won't this work?
    float new_theta = atan2(pos.x - past_pos.x, pos.y - past_pos.y);
    if (abs(new_theta - theta) > 0.1) {
      theta = new_theta;
    }
    pushMatrix();
    translate(pos.x, pos.y);
    rotate(-theta);
    image(sheepImg, 0, 0);
    popMatrix();
    past_pos.x = pos.x;
    past_pos.y = pos.y;
  }

  public void UpdateVecs(float dt) {
    pos.add(vel.times(dt));
    vel.add(accel.times(dt));
    if (vel.length() > max_speed) {
      vel = vel.normalized().times(max_speed);
    }
    // travel to other side of screen so sheep can never leave this way
    if (pos.x < 0) pos.x += width;
    if (pos.x > width) pos.x -= width;
    if (pos.y < 0) pos.y += height;
    if (pos.y > height) pos.y -= height;
  }
}

class Pen{
  Vec2 center;
  float x;
  float y;
  PShape shape;
  
  Pen(float x_, float y_){
    x = x_;
    y = y_;
    center = new Vec2(width/2, height/2);
    shape = createShape();
    shape.beginShape();
    shape.vertex(width/2 - x + 30, height/2 + y - 20);
    shape.vertex(width/2 - x + 30, height/2 + y);
    shape.vertex(width/2 - x, height/2 + y);
    shape.vertex(width/2 - x, height/2 - y);
    shape.vertex(width/2 + x, height/2 - y);
    shape.vertex(width/2 + x, height/2 + y);
    shape.vertex(width/2 + x - 30, height/2 + y);
    shape.vertex(width/2 + x - 30, height/2 + y - 20);
    shape.endShape(CLOSE);
    shape.setFill(color(82, 64, 47));
    shape.setStroke(color(150));
  }
  
  void drawPen(){
    shape(shape);
    fill(0);
    textSize(16);
    textAlign(CENTER);
    text("Herd the sheep here.", width/2, height/2);
  }
  
  boolean CheckIfCollision(Vec2 object, boolean AOE){
    if (AOE) {
      float sensing_len = 60;
      if ((object.x >= width/2 - x - sensing_len) && (object.x <= width/2 + x + sensing_len) && 
      (object.y >= height/2 - y - sensing_len/2) && (object.y <= height/2 + y + 8)){
        return true;
      }
    }
    else{
      if ((object.x >= width/2 - x) && (object.x <= width/2 + x) && 
      (object.y >= height/2 - y) && (object.y <= height/2 + y)){
        return true;
      }
    }
    return false;
  }
  
  boolean CheckToDelete(Vec2 sheepPos){
    if (
    (sheepPos.y >= (Enclosure.center.y + Enclosure.y - 5)) &&
    (sheepPos.y <= (Enclosure.center.y + Enclosure.y + 1)) &&
    (sheepPos.x >= (Enclosure.center.x - Enclosure.x + 20)) &&
    (sheepPos.x <= (Enclosure.center.x + Enclosure.x - 20)) ){
      return true;
    }
    return false;
  }
}
